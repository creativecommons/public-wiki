#!/bin/bash
set -o errexit
set -o nounset

# https://en.wikipedia.org/wiki/ANSI_escape_code
E0="$(printf "\e[0m")"        # reset
E31="$(printf "\e[31m")"      # foreground: red
E90="$(printf "\e[90m")"      # foreground: bright black (gray)
E94="$(printf "\e[94m")"      # foreground: bright blue
E97="$(printf "\e[97m")"      # foreground: bright white
CONF_PATH='/etc/mediawiki'
REQUIRED_VARIABLES=(
    MYSQL_DATABASE
    MYSQL_ROOT_PASSWORD
    MYSQL_USER
    MW_ADMIN_PASS
    MW_ADMIN_USER
    MW_DB_HOST
    MW_DB_PORT
    MW_SERVER_URL
    MW_SITENAME
)


# Ensure all vars are set
for _variable in "${REQUIRED_VARIABLES[@]}"
do
    if [[ -z "${!_variable:-}" ]]
    then
        _msg1="${E31}ERROR: Required environment variable is not set:"
        _msg2=" ${_variable}${E0}"
        echo "${_msg1}${_msg2}"
        # Use exit code 0 to avoid triggering restart: on-failure
        exit 0
    fi
done
echo "${E90}All required environment variables are present${E90}"


echo "Waiting for database at ${MW_DB_HOST}:${MW_DB_PORT}..."
while ! (echo > "/dev/tcp/${MW_DB_HOST}/${MW_DB_PORT}") >/dev/null 2>&1
do
    echo "${E90}Database not reachable yet. Retrying in 1s...${E0}"
    sleep 1
done
echo 'Database is up!'


# Install MediaWiki, if necessary
if [[ ! -f "${CONF_PATH}/LocalSettings.php" ]]
then
    echo 'Beginning MediaWiki installation'
    /usr/bin/php /usr/share/mediawiki/maintenance/run.php install \
        --confpath="${CONF_PATH}" \
        --dbname="${MYSQL_DATABASE}" \
        --dbpass="${MYSQL_ROOT_PASSWORD}" \
        --dbserver="${MW_DB_HOST}:${MW_DB_PORT}" \
        --dbuser="${MYSQL_USER}" \
        --pass "${MW_ADMIN_PASS}" \
        --scriptpath="" \
        --server="${MW_SERVER_URL}" \
        "${MW_SITENAME}" "${MW_ADMIN_USER}"
    # shellcheck disable=SC2016
    echo '$wgArticlePath = "/wiki/$1";' >> "${CONF_PATH}/LocalSettings.php"
    echo 'MediaWiki installation complete'
else
    echo "${E90}Skipping MediaWiki installation (config present)${E0}"
fi


/sbin/apache2ctl -v
echo "${E97}Starting apache2 webserver: ${E94}${MW_SERVER_URL}/${E0}"
/sbin/apache2ctl -D FOREGROUND -k start
