#!/bin/bash
set -o errexit
set -o nounset

# https://en.wikipedia.org/wiki/ANSI_escape_code
E0="$(printf "\e[0m")"        # reset
E1="$(printf "\e[1m")"        # bold
CONF_PATH='/etc/mediawiki'
REQUIRED_VARS=(
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
WEB_ROOT='/var/lib/mediawiki'


# Ensure all vars are set
for var in "${REQUIRED_VARS[@]}"
do
  if [[ -z "${var:-}" ]]
  then
    echo "ERROR: Required environment variable ${var} is not set"
    exit 1
  fi
done
echo 'All required environment variables are present'


echo "Waiting for database at ${MW_DB_HOST}:${MW_DB_PORT}..."
while ! (echo > /dev/tcp/${MW_DB_HOST}/${MW_DB_PORT}) >/dev/null 2>&1
do
  echo "Database not reachable yet. Retrying in 1s..."
  sleep 1
done
echo 'Database is up!'


# Install MediaWiki, if necessary
if [[ ! -f "${CONF_PATH}/LocalSettings.php" ]]
then
  echo 'Beginning MediaWiki installation'
  /usr/bin/php /usr/share/mediawiki/maintenance/install.php \
    --confpath="${CONF_PATH}" \
    --dbname="${MARIADB_DATABASE}" \
    --dbpass="${MARIADB_ROOT_PASSWORD}" \
    --dbserver="${MW_DB_HOST}:${MW_DB_PORT}" \
    --dbuser="${MARIADB_USER}" \
    --pass "${MW_ADMIN_PASS}" \
    --scriptpath="" \
    --server="${MW_SERVER_URL}" \
    "$MW_SITENAME" "${MW_ADMIN_USER}"
  #chmod 600 /var/www/wiki/LocalSettings.php
  #chown www-data:www-data /var/www/wiki/LocalSettings.php
  ln -s "${CONF_PATH}/LocalSettings.php" "${WEB_ROOT}/LocalSettings.php"
  echo 'MediaWiki installation complete'
else
  echo 'Skipping MediaWiki installation (LocalSettings.php already exists)'
fi


/sbin/apache2ctl -v
# Start Apache in the foreground
echo "${E1}Starting apache2 webserver: http://localhost:8080/${E0}"
/sbin/apache2ctl -D FOREGROUND -k start
