#!/bin/bash
set -o errexit
set -o errtrace
set -o nounset

# shellcheck disable=2154
trap '_es=${?};
    printf "${0}: line ${LINENO}: \"${BASH_COMMAND}\"";
    printf " exited with a status of ${_es}\n";
    exit ${_es}' ERR

# https://en.wikipedia.org/wiki/ANSI_escape_code
E0="$(printf "\e[0m")"        # reset
E31="$(printf "\e[31m")"      # foreground: red
E90="$(printf "\e[90m")"      # foreground: bright black (gray)
E94="$(printf "\e[94m")"      # foreground: bright blue
E97="$(printf "\e[97m")"      # foreground: bright white
CONFIG_VARIABLES=(
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
if [[ "${MW_SERVER_URL}" =~ ^http://localhost ]]
then
    CONTAINER_ENV=dev
else
    CONTAINER_ENV=prod
fi
export CONTAINER_ENV
WEB_URL="${MW_SERVER_URL}/"


error_exit() {
    echo "${E31}ERROR: ${1}${E0}" 1>&2
    # Use exit code 0 to avoid triggering restart: on-failure
    exit 0
}


# Ensure all configuration vars are set
for _variable in "${CONFIG_VARIABLES[@]}"
do
    if [[ -z "${!_variable:-}" ]]
    then
        error_exit "Required environment variable is not set: ${_variable}"
    fi
done
echo "${E90}All required environment variables are present${E90}"


while ! (echo > "/dev/tcp/${MW_DB_HOST}/${MW_DB_PORT}") >/dev/null 2>&1
do
    echo -n "${E90}Database  at ${MW_DB_HOST}:${MW_DB_PORT} is unreachable."
    echo " Retrying in 1s...${E0}"
    sleep 1
done
echo 'Database is up!'


# Configure Apache2
/usr/local/sbin/configure_apache2.sh

# Configure mount
/usr/local/sbin/configure_mount.sh

# Configure msmtp
/usr/local/sbin/configure_msmtp.sh

# Configure MW (MediaWiki)
/usr/local/sbin/configure_mediawiki.sh


# Unset configuration variables so that they are not available to Apache2
for _variable in "${CONFIG_VARIABLES[@]}"
do
    unset "${_variable}"
done


# Prepare for MediaWiki file cache
mkdir -p /tmp/mediawiki_file_cache
chown www-data:www-data /tmp/mediawiki_file_cache

/sbin/apache2ctl -v
echo "${E97}Starting apache2 webserver: ${E94}${WEB_URL}${E0}"
/sbin/apache2ctl -D FOREGROUND -k start
