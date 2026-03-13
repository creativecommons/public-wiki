#!/bin/bash
set -o errexit
set -o nounset

# https://en.wikipedia.org/wiki/ANSI_escape_code
E0="$(printf "\e[0m")"        # reset
E1="$(printf "\e[1m")"        # bold


# Ensure all vars are set
required_vars=(
  MARIADB_DATABASE
  MARIADB_ROOT_PASSWORD
  MARIADB_USER
  MW_ADMIN_PASS
  MW_ADMIN_USER
  MW_DB_HOST
  MW_DB_PORT
  MW_SERVER_URL
  MW_SITENAME
)
for var in "${required_vars[@]}"
do
  if [[ -z "${var:-}" ]]
  then
    echo "ERROR: Required environment variable ${var} is not set."
    exit 1
  fi
done
echo 'All required environment variables are present.'


DB_HOST=${MW_DB_HOST}
DB_PORT=${MW_DB_PORT}
echo "Waiting for database at ${DB_HOST}:${DB_PORT}..."
while ! (echo > /dev/tcp/${DB_HOST}/${DB_PORT}) >/dev/null 2>&1
do
  echo "Database not reachable yet. Retrying in 1s..."
  sleep 1
done
echo 'Database is up!'


# Install MediaWiki, if necessary
cd /var/www/wiki
if [[ ! -f /var/www/wiki/LocalSettings.php ]]
then
  echo 'Running MediaWiki installation...'
  php maintenance/install.php \
    --confpath='/var/www/wiki' \
    --dbname="${MARIADB_DATABASE}" \
    --dbpass="${MARIADB_ROOT_PASSWORD}" \
    --dbserver="${MW_DB_HOST}:${MW_DB_PORT}" \
    --dbuser="${MARIADB_USER}" \
    --pass "${MW_ADMIN_PASS}" \
    --scriptpath="" \
    --server="${MW_SERVER_URL}" \
    "$MW_SITENAME" "${MW_ADMIN_USER}"
  chmod 660 /var/www/wiki/LocalSettings.php
  chown www-data:www-data /var/www/wiki/LocalSettings.php
  echo 'Installation complete, LocalSettings.php is available.'
else
  echo 'LocalSettings.php already exists — skipping installation.'
fi


/sbin/apache2ctl -v
# Start Apache in the foreground
echo "${E1}Starting apache2 webserver: http://localhost:8080/${E0}"
/sbin/apache2ctl -D FOREGROUND -k start
