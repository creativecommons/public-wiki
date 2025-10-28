#!/bin/bash
set -o errexit
set -o nounset

# https://en.wikipedia.org/wiki/ANSI_escape_code
E0="$(printf "\e[0m")"        # reset
E1="$(printf "\e[1m")"        # bold

/sbin/apache2ctl -v

# Ensure all vars are set
required_vars=(
  MW_DB_HOST
  MW_DB_PORT
  MW_DB_NAME
  MW_DB_USER
  MW_DB_PASS
  MW_SERVER_URL
  MW_SITENAME
  MW_ADMIN_USER
  MW_ADMIN_PASS
)
for var in "${required_vars[@]}"; do
  if [[ -z "${!var:-}" ]]; then
    echo "ERROR: Required environment variable '$var' is not set."
    exit 1
  fi
done
echo "All required environment variables are present."


DB_HOST=${WIKI_DB_HOST:-wiki-db}
DB_PORT=${WIKI_DB_PORT:-3306}

echo "Waiting for database at ${DB_HOST}:${DB_PORT}..."

# Note proper syntax for /dev/tcp — no colon between host and port
while ! (echo > /dev/tcp/${DB_HOST}/${DB_PORT}) >/dev/null 2>&1; do
  echo "Database not reachable yet. Retrying in 1s..."
  sleep 1
done

echo 'Database is up!'

chown -R www-data:www-data /var/www/wiki
chmod -R 755 /var/www/wiki
cd /var/www/wiki

# Check if LocalSettings already exists
if [[ ! -f /var/www/wiki/LocalSettings.php ]]; then
  echo "Running MediaWiki installation..."

  php maintenance/install.php \
    --dbname="$MW_DB_NAME" \
    --dbuser="$MW_DB_USER" \
    --dbpass="$MW_DB_PASS" \
    --dbserver="$MW_DB_HOST:$MW_DB_PORT" \
    --server="$MW_SERVER_URL" \
    --scriptpath="" \
    --confpath="/var/www/wiki" \
    "$MW_SITENAME" "$MW_ADMIN_USER" \
    --pass "$MW_ADMIN_PASS"
  
  chmod 600 /var/www/wiki/LocalSettings.php
  chown www-data:www-data /var/www/wiki/LocalSettings.php || true
  echo "Installation complete, LocalSettings.php is available."
else
  echo "LocalSettings.php already exists — skipping installation."
fi

# Start Apache in the foreground
echo "${E1}Starting apache2 webserver: http://localhost:8080/${E0}"
/sbin/apache2ctl -D FOREGROUND -k start
