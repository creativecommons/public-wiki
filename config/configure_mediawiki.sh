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

CONF_PATH='/etc/mediawiki'
# https://en.wikipedia.org/wiki/ANSI_escape_code
E0="$(printf "\e[0m")"        # reset
E90="$(printf "\e[90m")"      # foreground: bright black (gray)
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
MW_INSTALL='/usr/bin/php /usr/share/mediawiki/maintenance/run.php install'
VOCAB_REPO='https://raw.githubusercontent.com/creativecommons/vocabulary'


append() {
    echo "${@}" >> "${LOCAL_SETTINGS}"
}

bold() {
    printf "${E97}mw: %s${E0} ${E90}%s${E0}\n" "${1}" \
        "$(date --utc '+%F %T.%N %Z')"
}


bold 'Begin MediaWiki installation'


rm -f "${LOCAL_SETTINGS}"

# https://www.mediawiki.org/wiki/Manual:Install.php
${MW_INSTALL} \
    --confpath="${CONF_PATH}" \
    --dbname="${MYSQL_DATABASE}" \
    --dbpass="${MYSQL_ROOT_PASSWORD}" \
    --dbserver="${MW_DB_HOST}:${MW_DB_PORT}" \
    --dbuser="${MYSQLUSER}" \
    --installdbpass="${MYSQL_ROOT_PASSWORD}" \
    --installdbuser="${MYSQLUSER}" \
    --pass "${MW_ADMIN_PASS}" \
    --scriptpath="" \
    --server="${MW_SERVER_URL}" \
    --skins=Vector \
    "${MW_SITENAME}" "${MW_ADMIN_USER}" \
    | sed --regexp-extended \
        -e'/^The environment has been checked. You can install MediaWiki\.$/d' \
        -e'/^Warning: Your default directory for.*not checked.*install\.$/d' \
        -e'/^Warning: Because of a connection error, it was not.*uploads\.$/d' \
        -e'/^done$/d' \
        -e'/^MediaWiki has been successfully installed\..*on that page\.$/d' \
        -e's/^/mw: /' \
        -e"s/^(mw: Warning:.*)\$/${E90}\1${E0}/"
# Full text of deleted lines:
# 1. The environment has been checked. You can install MediaWiki.
# 2. Warning: Your default directory for uploads (/usr/share/mediawiki/images/) is
#    not checked for vulnerability to arbitrary script execution during the CLI
#    install.
# 3. Warning: Because of a connection error, it was not possibly to verify that
#    images in your uploads directory, respond with the HTTP header
#    X-Content-Type-Options: nosniff to protect browsers from potentially unsafe
#    files. It is highly recommended to configure appropriate response headers on
#    your webserver before enabling uploads.
# 4. done [many occurances]
# 5. MediaWiki has been successfully installed. You can now visit [URL] to view
#    your wiki. If you have questions, check out our frequently asked questions
#    list: <https://www.mediawiki.org/wiki/Special:MyLanguage/Manual:FAQ> or
#    use one of the support forums linked on that page.

# https://www.mediawiki.org/wiki/Manual:$wgLogos
echo 'mw: Install logo ($wgLogos)'
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
echo 'mw: Install favicon ($wgFavicon)'
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


# https://www.mediawiki.org/wiki/Manual:$wgEnableUserEmail
echo 'mw: Configure user-to-user email ($wgEnableUserEmail)'
sed -e's|^\$wgEnableUserEmail = true;|$wgEnableUserEmail = false;|' \
    -i "${LOCAL_SETTINGS}"


# https://www.mediawiki.org/wiki/Manual:$wgPasswordSender
echo 'mw: Configure password reminder email address ($wgPasswordSender)'
_pass_sender="\$wgPasswordSender = \"${MW_EMAIL}\";"
sed -e"s|^\\\$wgPasswordSender = \"\";\$|${_pass_sender}|" \
    -i "${LOCAL_SETTINGS}"
unset _pass_sender


# https://www.mediawiki.org/wiki/Manual:$wgSessionCacheType
echo 'mw: Configure session cache ($wgSessionCacheType)'
_session_cache='$wgSessionCacheType = CACHE_DB;'
sed --regexp-extended --null-data \
    -e"s|(\\\$wgMainCacheType[^;]+;)|\\1\\n${_session_cache}|" \
    -i "${LOCAL_SETTINGS}"
unset _session_cache


# https://www.mediawiki.org/wiki/Manual:$wgUseFileCache
echo 'mw: Configure file cache ($wgUseFileCache, $wgFileCacheDirectory)'
_file_cache='$wgUseFileCache = true;\n$wgFileCacheDirectory ='
_file_cache="${_file_cache} \"/tmp/mediawiki_file_cache\";"
sed --regexp-extended --null-data \
    -e"s|(\\\$wgMemCachedServers[^;]+;)|\\1\\n${_file_cache}|" \
    -i "${LOCAL_SETTINGS}"
unset _file_cache


# https://www.mediawiki.org/wiki/Manual:Configuring_file_uploads
# https://www.mediawiki.org/wiki/Manual:$wgEnableUploads
echo 'mw: Enable Uploads ($wgEnableUploads)'
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
echo 'mw: Enable rights (CC BY 4.0, $wgRightsUrl, $wgRightsText, $wgRightsIcon)'
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
echo 'mw: Enable short URL ($wgArticlePath)'
append '# Enable short URL'
append '$wgArticlePath = "/wiki/$1";'


# https://www.mediawiki.org/wiki/Manual:$wgFileExtensions
echo 'mw: Add file extensions ($wgFileExtensions)'
append
append '# Additional file extensions'
echo -n "${E90}mw:"
for _ext in "${FILE_EXTENSIONS[@]}"
do
    append "\$wgFileExtensions[] = \"${_ext}\";"
    echo -n " ${_ext}"
done
echo "${E0}"


#append
#append '# Performance optimizations'
## https://www.mediawiki.org/wiki/Manual:Performance_tuning
#
## miser mode can't be enabled until scheduling is resolved
## https://www.mediawiki.org/wiki/Manual:$wgMiserMode
#bold 'Disable database-intensive features (performance, $wgMiserMode)'
#append '$wgMiserMode = true;'


append
append '# CDN caching'

# https://www.mediawiki.org/wiki/Manual:$wgCdnMaxAge
echo 'mw: Configure cache timeout ($wgCdnMaxAge)'
append '$wgCdnMaxAge = 3600;  # 1 hour'

# https://www.mediawiki.org/wiki/Manual:$wgUseCdn
echo 'mw: Enable CDN ($wgUseCdn)'
append '$wgUseCdn = true;'

case "${CONTAINER_ENV}" in
    dev)
        PREFIX='#-'
        NOTE="mw: [dev disabled]${E90}"
        append '#-Production configuration disabled in development'
        ;;
    prod)
        PREFIX='';
        NOTE='mw:';;
esac
# https://www.mediawiki.org/wiki/Manual:$wgCdnServersNoPurge
echo "${NOTE} Configure Cloudflare CDN IPs (\$wgCdnServersNoPurge)${E0}"
append "${PREFIX}\$wgCdnServersNoPurge = [];"
# shellcheck disable=2013
for _remote_ip in $(awk '/^#?-?RemoteIPTrustedProxy/ {print $2}' \
    /etc/apache2/conf-available/remoteip.conf)
do
    append "${PREFIX}\$wgCdnServersNoPurge[] = \"${_remote_ip}\";"
done


append
append '# Extensions'

# https://www.mediawiki.org/wiki/Extension:Cite
echo 'mw: Enable Cite extension'
append 'wfLoadExtension( "Cite" );'

# https://www.mediawiki.org/wiki/Extension:Nuke
echo 'mw: Enable Nuke extension'
append 'wfLoadExtension( "Nuke" );'


# https://www.mediawiki.org/wiki/Manual:$wgUseRCPatrol
echo 'mw: Disable recent changes patrolling ($wgUseRCPatrol)'
append
append '$wgUseRCPatrol = false;'


append
# https://www.mediawiki.org/wiki/Manual:User_rights
echo 'mw: Update group permissions / user rights'
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
'


bold 'End MediaWiki installation  '
