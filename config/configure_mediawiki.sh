#!/bin/bash
# shellcheck disable=SC2016
set -o errexit
set -o nounset

CONF_PATH='/etc/mediawiki'
# https://en.wikipedia.org/wiki/ANSI_escape_code
E0="$(printf "\e[0m")"        # reset
E97="$(printf "\e[97m")"      # foreground: bright white
FILE_EXTENSIONS=(
    doc
    docx
    indd
    m4v
    odp
    ods
    odt
    ogg
    pdf
    psd
    svg
    txt
    xcf
    xls
    zip
)
if [[ "${MW_SERVER_URL}" == 'http://localhost:8081' ]]
then
    MW_INSTALL='/usr/bin/php /usr/share/mediawiki/maintenance/install.php'
else
    MW_INSTALL='/usr/bin/php /usr/share/mediawiki/maintenance/run.php install'
fi
VOCAB_REPO='https://raw.githubusercontent.com/creativecommons/vocabulary'


bold() {
    printf "${E97}%s${E0}\n" "${@}"
}


bold 'Begin MediaWiki installation'
# https://www.mediawiki.org/wiki/Manual:Install.php
${MW_INSTALL} \
    --confpath="${CONF_PATH}" \
    --dbname="${MARIADB_DATABASE}" \
    --dbpass="${MARIADB_ROOT_PASSWORD}" \
    --dbserver="${MW_DB_HOST}:${MW_DB_PORT}" \
    --dbuser="${MARIADB_USER}" \
    --installdbpass="${MARIADB_ROOT_PASSWORD}" \
    --installdbuser="${MARIADB_USER}" \
    --pass "${MW_ADMIN_PASS}" \
    --scriptpath="" \
    --server="${MW_SERVER_URL}" \
    --skins=Vector \
    "${MW_SITENAME}" "${MW_ADMIN_USER}" \
    | sed --regexp-extended \
        -e'/^Warning:.*default directory for uploads.*not checked/d' \
        -e'/^Warning: Because of a connection error.*X-Content-Type-Options/d'

# https://www.mediawiki.org/wiki/Manual:$wgLogos
bold 'Install logo ($wgLogos)'
mkdir -p /var/lib/mediawiki/assets
curl --fail --location \
    --output /var/lib/mediawiki/assets/cc.svg \
    --silent --show-error \
    "${VOCAB_REPO}/refs/heads/main/src/svg/cc/logos/cc/lettermark.svg"
_logo=/assets/cc.svg
sed --regexp-extended \
    -e'/^\s+.1x. => "\$wgResourceBasePath/d' \
    -e"s|(^\\s+.icon. => \")\\\$wgResourceBasePath.*$|\\1${_logo}\",|" \
    -i "${CONF_PATH}/LocalSettings.php"
unset _logo

# https://www.mediawiki.org/wiki/Manual:$wgFavicon
bold 'Install favicon ($wgFavicon)'
mkdir -p /var/lib/mediawiki/assets
curl --fail --location \
    --output /var/lib/mediawiki/assets/favicon.ico \
    --silent --show-error \
    "${VOCAB_REPO}/refs/heads/main/src/favicon/favicon.ico"
_favicon=/assets/favicon.ico
sed --regexp-extended --null-data \
    -e"s|(\\\$wgLogos[^;]+;)|\\1\\n\$wgFavicon = \"${_favicon}\";|" \
    -i "${CONF_PATH}/LocalSettings.php"
unset _favicon

# https://www.mediawiki.org/wiki/Manual:$wgSessionCacheType
bold 'Configure session cache ($wgSessionCacheType)'
_session_cache='$wgSessionCacheType = CACHE_DB;'
sed --regexp-extended --null-data \
    -e"s|(\\\$wgMainCacheType[^;]+;)|\\1\\n${_session_cache}|" \
    -i "${CONF_PATH}/LocalSettings.php"
unset _session_cache

# https://www.mediawiki.org/wiki/Manual:$wgUseFileCache
bold 'Configure file cache ($wgUseFileCache, $wgFileCacheDirectory)'
_file_cache='$wgUseFileCache = true;\n$wgFileCacheDirectory ='
_file_cache="${_file_cache} \"/tmp/mediawiki_file_cache\";"
sed --regexp-extended --null-data \
    -e"s|(\\\$wgMemCachedServers[^;]+;)|\\1\\n${_file_cache}|" \
    -i "${CONF_PATH}/LocalSettings.php"
unset _file_cache

# https://www.mediawiki.org/wiki/Manual:Configuring_file_uploads
bold 'Enable Uploads ($wgEnableUploads)'
sed -e's|^\$wgEnableUploads = false;$|$wgEnableUploads = true;|' \
    -i "${CONF_PATH}/LocalSettings.php"

# https://www.mediawiki.org/wiki/Manual:$wgRightsUrl
# https://www.mediawiki.org/wiki/Manual:$wgRightsText
# https://www.mediawiki.org/wiki/Manual:$wgRightsIcon
bold 'Enable rights (CC BY 4.0, $wgRightsUrl, $wgRightsText, $wgRightsIcon)'
_wgRightsUrl='https://creativecommons.org/licenses/by/4.0/'
_wgRightsText='Creative Commons Attribution 4.0 International'
_wgRightsIcon='https://licensebuttons.net/l/by/4.0/88x31.png'
sed --regexp-extended \
    -e"s|^(.wgRightsUrl = \")(\";)|\\1${_wgRightsUrl}\\2|" \
    -e"s|^(.wgRightsText = \")(\";)|\\1${_wgRightsText}\\2|" \
    -e"s|^(.wgRightsIcon = \")(\";)|\\1${_wgRightsIcon}\\2|" \
    -i "${CONF_PATH}/LocalSettings.php"
unset _wgRightsUrl _wgRightsText _wgRightsIcon

# https://www.mediawiki.org/wiki/Manual:Short_URL/Apache
bold 'Enable short URL ($wgArticlePath)'
echo '$wgArticlePath = "/wiki/$1";' >> "${CONF_PATH}/LocalSettings.php"
echo >> "${CONF_PATH}/LocalSettings.php"

# https://www.mediawiki.org/wiki/Manual:$wgFileExtensions
bold 'Add file extensions ($wgFileExtensions)'
for _ext in "${FILE_EXTENSIONS[@]}"
do
    echo -n "  ${_ext}"
    echo "\$wgFileExtensions[] = '${_ext}';" \
        >> "${CONF_PATH}/LocalSettings.php"
done
echo

bold 'MediaWiki installation complete'
