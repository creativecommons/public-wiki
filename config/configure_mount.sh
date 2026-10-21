#!/bin/bash
# shellcheck disable=SC2016
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
E90="$(printf "\e[90m")"      # foreground: bright black (gray)
E97="$(printf "\e[97m")"      # foreground: bright white


bold() {
    printf "${E97}mount: %s${E0} ${E90}%s${E0}\n" "${1}" \
        "$(date --utc '+%F %T.%N %Z')"
}


bold 'Begin persistent volume configuration'


# Ensure MediaWiki volume is mounted
if ! mountpoint --quiet /mnt/wiki
then
    echo "${E31}ERROR: nothing mounted at /mnt/wiki${E0}" 1>&2
    # Use exit code 0 to avoid triggering restart: on-failure
    exit 0
fi

# Configure mountpoint subdirectories and symlinks
echo 'mount: Configure assets symlink'
mkdir --parents /mnt/wiki/var-lib-mediawiki-assets
if [[ "$(readlink --canonicalize /var/lib/mediawiki/assets)" \
    != '/mnt/wiki/var-lib-mediawiki-assets' ]]
then
    [[ -d '/var/lib/mediawiki/assets' ]] && rmdir /var/lib/mediawiki/assets
    ln --force --no-dereference --symbolic --no-target-directory \
        /mnt/wiki/var-lib-mediawiki-assets /var/lib/mediawiki/assets
fi

echo 'mount: Configure images symlink'
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

# TODO: remove this after initial deployment
E93="$(printf "\e[93m")"
echo "mount: Remove etc symlink ${E93}[TODO: remove this after initial \
deployment]${E0}"
mkdir --parents /mnt/wiki/etc-mediawiki
[[ -d /mnt/wiki/etc-mediawiki ]] && rm -rf /mnt/wiki/etc-mediawiki
[[ -h /etc/mediawiki ]] && rm -f /etc/mediawiki
mkdir -p /etc/mediawiki


bold 'End persistent volume configuration  '
