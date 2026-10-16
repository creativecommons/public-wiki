#!/bin/bash
set -o errexit
set -o nounset

# https://en.wikipedia.org/wiki/ANSI_escape_code
E0="$(printf "\e[0m")"        # reset
E31="$(printf "\e[31m")"      # foreground: red
E90="$(printf "\e[90m")"      # foreground: bright black (gray)
E94="$(printf "\e[94m")"      # foreground: bright blue
E97="$(printf "\e[97m")"      # foreground: bright white
REQUIRED_VARIABLES=(
    DMA_AUTH_PASS
    DMA_AUTH_USER
    DMA_PORT
    DMA_ROOT_ALIAS
    DMA_SMARTHOST
    MW_ADMIN_PASS
    MW_ADMIN_USER
    MW_DB_HOST
    MW_DB_PORT
    MW_EMAIL
    MW_SERVER_URL
    MW_SITENAME
    MYSQLUSER
    MYSQL_DATABASE
    MYSQL_ROOT_PASSWORD
)
if [[ "${MW_SERVER_URL}" == 'http://localhost:8081' ]]
then
    CONTAINER='web-bullseye'
else
    CONTAINER='web'
fi
export CONTAINER


error_exit() {
    echo "${E31}ERROR: ${1}${E0}" 1>&2
    # Use exit code 0 to avoid triggering restart: on-failure
    exit 0
}


# Ensure all vars are set
for _variable in "${REQUIRED_VARIABLES[@]}"
do
    if [[ -z "${!_variable:-}" ]]
    then
        error_exit "Required environment variable is not set: ${_variable}"
    fi
done
echo "${E90}All required environment variables are present${E90}"


# Configure mount
/usr/local/sbin/configure_mount.sh

# Configure dma (DragonFly Mail Agent)
/usr/local/sbin/configure_dma.sh

# Configure misc (miscellaneous)
/usr/local/sbin/configure_misc.sh


echo "Waiting for database at ${MW_DB_HOST}:${MW_DB_PORT}..."
while ! (echo > "/dev/tcp/${MW_DB_HOST}/${MW_DB_PORT}") >/dev/null 2>&1
do
    echo "${E90}Database not reachable yet. Retrying in 1s...${E0}"
    sleep 1
done
echo 'Database is up!'


# Configure MW (MediaWiki)
/usr/local/sbin/configure_mediawiki.sh


if [[ "${CONTAINER}" == 'web' ]]
then
    # Prepare for MediaWiki file cache
    mkdir -p /tmp/mediawiki_file_cache
    chown www-data:www-data /tmp/mediawiki_file_cache

    /sbin/apache2ctl -v
    echo "${E97}Starting apache2 webserver: ${E94}${MW_SERVER_URL}/${E0}"
    /sbin/apache2ctl -D FOREGROUND -k start
else
    echo "${E97}Sleeping 💤${E0}"
    while true; do sleep 5 || break; done
fi
