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
    MW_INSTALL='/usr/bin/php /usr/share/mediawiki/maintenance/install.php'
    APACHECTL='/usr/sbin/apache2ctl'
else
    CONTAINER='web'
    MW_INSTALL='/usr/bin/php /usr/share/mediawiki/maintenance/run.php install'
    APACHECTL='/sbin/apache2ctl'
fi


echo "Waiting for database at ${MW_DB_HOST}:${MW_DB_PORT}..."
while ! (echo > "/dev/tcp/${MW_DB_HOST}/${MW_DB_PORT}") >/dev/null 2>&1
do
    echo "${E90}Database not reachable yet. Retrying in 1s...${E0}"
    sleep 1
done
echo 'Database is up!'


# Install MediaWiki and configure, if necessary
if [[ ! -f "${CONF_PATH}/LocalSettings.php" ]]
then
    echo 'Beginning MediaWiki installation'
    ${MW_INSTALL} \
        --confpath="${CONF_PATH}" \
        --dbname="${MARIADB_DATABASE}" \
        --dbpass="${MARIADB_ROOT_PASSWORD}" \
        --dbserver="${MW_DB_HOST}:${MW_DB_PORT}" \
        --dbuser="${MARIADB_USER}" \
        --pass "${MW_ADMIN_PASS}" \
        --scriptpath="" \
        --server="${MW_SERVER_URL}" \
        "${MW_SITENAME}" "${MW_ADMIN_USER}"

    # https://www.mediawiki.org/wiki/Manual:Configuring_file_uploads
    echo 'Enabling Uploads (wgEnableUploads)'
    # shellcheck disable=SC2016
    sed -e's|^\$wgEnableUploads = false;$|$wgEnableUploads = true;|' \
        -i "${CONF_PATH}/LocalSettings.php"

    # https://www.mediawiki.org/wiki/Manual:$wgRightsUrl
    # https://www.mediawiki.org/wiki/Manual:$wgRightsText
    # https://www.mediawiki.org/wiki/Manual:$wgRightsIcon
    echo 'Enabling CC BY 4.0 (wgRightsUrl, wgRightsText, wgRightsIcon)'
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
    echo 'Enabling Short URL (wgArticlePath)'
    # shellcheck disable=SC2016
    echo '$wgArticlePath = "/wiki/$1";' >> "${CONF_PATH}/LocalSettings.php"

    # https://www.mediawiki.org/wiki/Manual:$wgFileExtensions
    echo 'Adding file extensions (wgFileExtensions)'
    for _ext in "${FILE_EXTENSIONS[@]}"
    do
        echo -n "  ${_ext}"
        echo "\$wgFileExtensions[] = '${_ext}';" \
            >> "${CONF_PATH}/LocalSettings.php"
    done
    echo

    echo 'MediaWiki installation complete'
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
