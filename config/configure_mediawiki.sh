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
LOCAL_SETTINGS="${CONF_PATH}/LocalSettings.php"
if [[ "${MW_SERVER_URL}" == 'http://localhost:8081' ]]
then
    MW_INSTALL='/usr/bin/php /usr/share/mediawiki/maintenance/install.php'
else
    MW_INSTALL='/usr/bin/php /usr/share/mediawiki/maintenance/run.php install'
fi
VOCAB_REPO='https://raw.githubusercontent.com/creativecommons/vocabulary'


append() {
    echo "${@}" >> "${LOCAL_SETTINGS}"
}

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
    -i "${LOCAL_SETTINGS}"
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
    -i "${LOCAL_SETTINGS}"
unset _session_cache

# https://www.mediawiki.org/wiki/Manual:$wgUseFileCache
bold 'Configure file cache ($wgUseFileCache, $wgFileCacheDirectory)'
_file_cache='$wgUseFileCache = true;\n$wgFileCacheDirectory ='
_file_cache="${_file_cache} \"/tmp/mediawiki_file_cache\";"
sed --regexp-extended --null-data \
    -e"s|(\\\$wgMemCachedServers[^;]+;)|\\1\\n${_file_cache}|" \
    -i "${LOCAL_SETTINGS}"
unset _file_cache

# https://www.mediawiki.org/wiki/Manual:Configuring_file_uploads
# https://www.mediawiki.org/wiki/Manual:$wgEnableUploads
bold 'Enable Uploads ($wgEnableUploads)'
sed -e's|^\$wgEnableUploads = false;$|$wgEnableUploads = true;|' \
    -i "${LOCAL_SETTINGS}"
for _file in /etc/php/8.4/apache2/php.ini /etc/php/8.4/cli/php.ini
do
    sed -e's|^post_max_size = .*$|post_max_size = 20M|' \
        -e's|upload_max_filesize = .*$|upload_max_filesize = 20M|' \
        -i "${_file}"
done

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
    -i "${LOCAL_SETTINGS}"
unset _wgRightsUrl _wgRightsText _wgRightsIcon

# https://www.mediawiki.org/wiki/Manual:Short_URL/Apache
bold 'Enable short URL ($wgArticlePath)'
append '# Enable short URL'
append '$wgArticlePath = "/wiki/$1";'
append

# https://www.mediawiki.org/wiki/Manual:$wgFileExtensions
bold 'Add file extensions ($wgFileExtensions)'
append '# Additional file extensions'
for _ext in "${FILE_EXTENSIONS[@]}"
do
    append "\$wgFileExtensions[] = \"${_ext}\";"
    echo -n "  ${_ext}"
done
append
echo


# https://www.mediawiki.org/wiki/Manual:User_rights
bold 'Update group permissions / user rights'
append '# Group permissions / user rights

# Only allow SysOps to create accounts instead of * (all) group
$wgGroupPermissions["sysop"]["createaccount"] = true;
$wgGroupPermissions["*"]["createaccount"] = false;

# Move basic permissions to user group from * (all) group
$_basicPermissions = [
    "createpage",
    "createtalk",
    "edit",
    "editmyoptions",
    "editmyprivateinfo",
    "viewmyprivateinfo",
];
foreach ($_basicPermissions as $_permission) {
  $wgGroupPermissions["user"][$_permission] = true;
  $wgGroupPermissions["*"][$_permission] = false;
}

# Remove legacy CC groups
$_legacyCcGroups = [
    "affiliate",
    "approved",
    "community",
    "regional",
    "staff",
];
foreach ($_legacyCcGroups as $_group) {
    unset( $wgGroupPermissions[$_group] );
    unset( $wgRevokePermissions[$_group] );
    unset( $wgAddGroups[$_group] );
    unset( $wgRemoveGroups[$_group] );
    unset( $wgGroupsAddToSelf[$_group] );
    unset( $wgGroupsRemoveFromSelf[$_group] );
}
'


append '# Performance optimizations'

# https://www.mediawiki.org/wiki/Manual:$wgDisableCounters
bold 'Disable counters (performance, $wgDisableCounters)'
append '$wgDisableCounters = true;'

# miser mode can't be enabled until scheduling is resolved
## https://www.mediawiki.org/wiki/Manual:$wgDisableCounters
#bold 'Disable database-intensive features (performance, $wgMiserMode)'
#append '$wgMiserMode = true;'


append '# Extensions'
# https://www.mediawiki.org/wiki/Extension:Cite
bold 'Enable Cite extension'
append 'wfLoadExtension( "Cite" );'
# https://www.mediawiki.org/wiki/Extension:Nuke
bold 'Enable Nuke extension'
append 'wfLoadExtension( "Nuke" );'


#https://www.mediawiki.org/wiki/Manual:$wgUseRCPatrol
bold 'Disable recent changes patrolling ($wgUseRCPatrol)'
append '$wgUseRCPatrol = false;'


bold 'MediaWiki installation complete'
