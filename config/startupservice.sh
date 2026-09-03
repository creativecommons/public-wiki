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
    MYSQL_DATABASE
    MYSQL_ROOT_PASSWORD
    MYSQLUSER
    MW_ADMIN_PASS
    MW_ADMIN_USER
    MW_DB_HOST
    MW_DB_PORT
    MW_SERVER_URL
    MW_SITENAME
)


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

# Ensure volume is mounted
mountpoint --quiet /mnt/wiki || error_exit 'nothing mounted at /mnt/wiki'


# Configure mountpoint subdirectories and symlinks
mkdir --parents /mnt/wiki/var-lib-mediawiki-assets
if [[ "$(readlink --canonicalize /var/lib/mediawiki/assets)" \
    != '/mnt/wiki/var-lib-mediawiki-assets' ]]
then
    [[ -d '/var/lib/mediawiki/assets' ]] && rmdir /var/lib/mediawiki/assets
    ln --force --no-dereference --symbolic --no-target-directory \
        /mnt/wiki/var-lib-mediawiki-assets /var/lib/mediawiki/assets
fi

mkdir --parents /mnt/wiki/etc-mediawiki
if [[ "$(readlink --canonicalize /etc/mediawiki)" \
    != /mnt/wiki/etc-mediawiki ]]
then
    [[ -d /etc/mediawiki ]] && rmdir /etc/mediawiki
    ln --force --no-dereference --symbolic --no-target-directory \
        /mnt/wiki/etc-mediawiki /etc/mediawiki
fi

mkdir --parents \
    /mnt/wiki/var-lib-mediawiki-images
chmod 0700 /mnt/wiki/var-lib-mediawiki-images
chown www-data:www-data /mnt/wiki/var-lib-mediawiki-images
if [[ "$(readlink --canonicalize /var/lib/mediawiki/images)" \
    != /mnt/wiki/var-lib-mediawiki-images ]]
then
    if [[ -d /var/lib/mediawiki/images ]]
    then
        [[ -f /var/lib/mediawiki/images/.htaccess ]] \
            && mv /var/lib/mediawiki/images/.htaccess \
                /mnt/wiki/var-lib-mediawiki-images/
        [[ -f /var/lib/mediawiki/images/README ]] \
            && mv /var/lib/mediawiki/images/README \
                /mnt/wiki/var-lib-mediawiki-images/
        rmdir /var/lib/mediawiki/images
    fi
    ln --force --no-dereference --symbolic --no-target-directory \
        /mnt/wiki/var-lib-mediawiki-images /var/lib/mediawiki/images
fi


if [[ "${MW_SERVER_URL}" == 'http://localhost:8081' ]]
then
    CONTAINER='web-bullseye'
else
    CONTAINER='web'
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
    if [[ "${CONTAINER}" == 'web' ]]
    then
        echo -n 'Waiting 5 seconds so that web-bullseye can complete install'
        echo ' first'
        sleep 5
    fi
    /usr/local/sbin/configure_mediawiki.sh
else
    echo "${E90}Skipping MediaWiki installation (config present)${E0}"
fi

if [[ "${CONTAINER}" == 'web' ]]
then
    # Prepare for MediaWiki file cache
    mkdir -p /tmp/mediawiki_file_cache
    chown www-data:www-data /tmp/mediawiki_file_cache

    /sbin/apache2ctl -v
    echo "${E97}Starting apache2 webserver: ${E94}${MW_SERVER_URL}/${E0}"
    /sbin/apache2ctl -D FOREGROUND -k start
else
    echo "${E97}Sleeping 😴${E0}"
    while true; do sleep 5 || break; done
fi
