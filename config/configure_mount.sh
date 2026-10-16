#!/bin/bash
# shellcheck disable=SC2016
set -o errexit
set -o nounset

# https://en.wikipedia.org/wiki/ANSI_escape_code
E0="$(printf "\e[0m")"        # reset
E97="$(printf "\e[97m")"      # foreground: bright white


bold() {
    printf "${E97}%s${E0}\n" "${@}"
}


# Ensure MediaWiki volume is mounted
mountpoint --quiet /mnt/wiki || error_exit 'nothing mounted at /mnt/wiki'


bold 'Begin mount configuration'

# Configure mountpoint subdirectories and symlinks
echo '  mount: Configure assets symlink'
mkdir --parents /mnt/wiki/var-lib-mediawiki-assets
if [[ "$(readlink --canonicalize /var/lib/mediawiki/assets)" \
    != '/mnt/wiki/var-lib-mediawiki-assets' ]]
then
    [[ -d '/var/lib/mediawiki/assets' ]] && rmdir /var/lib/mediawiki/assets
    ln --force --no-dereference --symbolic --no-target-directory \
        /mnt/wiki/var-lib-mediawiki-assets /var/lib/mediawiki/assets
fi

echo '  mount: Configure etc symlink'
mkdir --parents /mnt/wiki/etc-mediawiki
if [[ "$(readlink --canonicalize /etc/mediawiki)" \
    != /mnt/wiki/etc-mediawiki ]]
then
    [[ -d /etc/mediawiki ]] && rmdir /etc/mediawiki
    ln --force --no-dereference --symbolic --no-target-directory \
        /mnt/wiki/etc-mediawiki /etc/mediawiki
fi

echo '  mount: Configure images symlink'
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


bold 'End mount configuration'
