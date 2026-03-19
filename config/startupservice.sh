#!/bin/bash
set -o errexit
set -o nounset

CONF_PATH='/etc/mediawiki'
# https://en.wikipedia.org/wiki/ANSI_escape_code
E0="$(printf "\e[0m")"        # reset
E31="$(printf "\e[31m")"      # foreground: red
E90="$(printf "\e[90m")"      # foreground: bright black (gray)
E94="$(printf "\e[94m")"      # foreground: bright blue
E97="$(printf "\e[97m")"      # foreground: bright white
REQUIRED_VARIABLES=(
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


if [[ "${MW_SERVER_URL}" == 'http://localhost:8081' ]]
then
    CONTAINER='web-bullseye'
    APACHECTL='/usr/sbin/apache2ctl'
else
    CONTAINER='web'
    APACHECTL='/sbin/apache2ctl'
fi


echo "Waiting for database at ${MW_DB_HOST}:${MW_DB_PORT}..."
while ! (echo > "/dev/tcp/${MW_DB_HOST}/${MW_DB_PORT}") >/dev/null 2>&1
do
    echo "${E90}Database not reachable yet. Retrying in 1s...${E0}"
    sleep 1
done
echo 'Database is up!'


# Install and configure MediaWiki, if necessary
if [[ ! -f "${CONF_PATH}/LocalSettings.php" ]]
then
    /usr/local/sbin/configure_mediawiki.sh
else
    echo "${E90}Skipping MediaWiki installation (config present)${E0}"
fi


if [[ "${CONTAINER}" == 'web' ]]
then
    "${APACHECTL}" -v
    echo "${E97}Starting apache2 webserver: ${E94}${MW_SERVER_URL}/${E0}"
    "${APACHECTL}" -D FOREGROUND -k start
else
    echo "${E97}Sleeping 😴${E0}"
    while true; do sleep 5 || break; done
fi
