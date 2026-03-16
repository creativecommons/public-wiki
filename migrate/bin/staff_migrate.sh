#!/bin/bash
#
# Notes:
# - This script can only be run by Creative Commons (CC) staff--it requires
#   shell access to the legacy production server
# - If you modify this file, please re-check it with shellcheck
# - '| xargs' is used to trim whitespace
set -o errexit
set -o errtrace
set -o nounset

# shellcheck disable=SC2154
trap '_es=${?};
    printf "${0}: line ${LINENO}: \"${BASH_COMMAND}\"";
    printf " exited with a status of ${_es}\n";
    exit ${_es}' ERR

DIR_MIGRATE="$(cd -P -- "${0%/*}/.." && pwd -P)"
DOCKER_MW_DIR=/var/lib/mediawiki
# https://en.wikipedia.org/wiki/ANSI_escape_code
E0="$(printf "\e[0m")"        # reset
E1="$(printf "\e[1m")"        # bold
E30="$(printf "\e[30m")"      # foreground: black
E31="$(printf "\e[31m")"      # foreground: red
E33="$(printf "\e[33m")"      # foreground: yellow
E43="$(printf "\e[43m")"      # foreground: yellow
E90="$(printf "\e[90m")"      # foreground: bright black (gray)
E92="$(printf "\e[92m")"      # foreground: bright green
E93="$(printf "\e[93m")"      # foreground: bright yellow
E97="$(printf "\e[97m")"      # foreground: bright white
E100="$(printf "\e[100m")"    # background: bright black (gray)
E107="$(printf "\e[107m")"    # background: bright white
PROD_SERVER=wiki.default.creativecommons.uk0.bigv.io
PROD_IMAGES_DIR=/var/www/images/
PROD_MW_DB=ccwiki
PROD_MW_HOST=wiki.creativecommons.org
declare -i RSYNC_PROT_VER_MIN=31
SCRIPT_NAME="${0##*/}"
# The configure_environment() function sets the following global variables:
CACHE_SQL=''
CACHE_DIR=''
CACHE_IMAGES_DIR=''
DOCKER_SQL=''
DOCKER_MW_IMAGES_DIR=''
# The parse_command() function sets the following global variables:
COMMAND=''
# The rsync_version() function sets the following global variables:
declare -i RSYNC_PROT_VER=0


#### FUNCTIONS ################################################################


bold() {
    printf "${E1}%s${E0}\n" "${@}"
}


danger_confirm() {
    local _confirm _i _prompt _rand

    if [[ "${DANGER_BYPASS:-}" == 'i will be careful' ]]
    then
        return
    fi

    printf "${E43}${E30} %-71s$(date '+%T') ${E0}\n" \
        'Confirmation required'
    echo -e "${E33}WARNING:${E0} the '${COMMAND}' command is destructive"
    # Loop until user enters random number
    _rand=${RANDOM}${RANDOM}${RANDOM}
    _rand=${_rand:0:4}
    _prompt="Type the number, ${_rand}, to continue: "
    _i=0
    while read -p "${_prompt}" -r _confirm
    do
        if [[ "${_confirm}" == "${_rand}" ]]
        then
            echo
            return
        fi
        (( _i > 1 )) && error_exit 'invalid confirmation number'
        _i=$(( ++_i ))
    done
}


delete_mediawiki_images() {
    local _count
    header 'Delete MediaWiki images from container'
    print_var DOCKER_MW_IMAGES_DIR
    echo -n 'Deleting contents of images directory:'
    echo " ${DOCKER_MW_IMAGES_DIR}/*"
    # (xargs is used to trim whitespace)
    _count=$(docker compose exec --user root web \
        sh -c "rm -frv ${DOCKER_MW_IMAGES_DIR}/* | wc -l | xargs")
    success "Directories/files removed: ${_count}"
    echo
}


error_exit() {
    # Echo error message and exit with error
    echo -e "${E31}ERROR:${E0} ${*}" 1>&2
    exit 1
}


header() {
    # Print 80 character wide black on white heading
    printf "${E30}${E107} %-71s$(date '+%T') ${E0}\n" "${@}"
}


import_database() {
    header 'Import data into container database'
    print_var DOCKER_SQL
    echo 'Importing database dump SQL on web-bullseye'
    docker compose exec web-bullseye /usr/bin/php \
        /usr/share/mediawiki/maintenance/sql.php --quiet "${DOCKER_SQL}"
    echo
}


import_images() {
    header 'Import images into container'
    print_var CACHE_IMAGES_DIR
    print_var DOCKER_MW_IMAGES_DIR
    echo 'Copy cache images to docker temp images dir'
    find "${CACHE_IMAGES_DIR}/"* -maxdepth 0 -print0 \
        | xargs --null -I {} docker compose cp {} "web:${DOCKER_MW_IMAGES_DIR}"
    echo 'Set ownership of entire images dir to www-data:wwww-data'
    docker compose exec --user root web chown -R www-data:www-data \
        "${DOCKER_MW_IMAGES_DIR}"
    echo
}


migrate_database() {
    header 'Migrate container database'
    # https://www.mediawiki.org/wiki/Manual:Update.php
    echo 'Migrating MediaWiki from 1.30.0 (Bytemark) to 1.35.13 (web-bullseye)'
    docker compose exec web-bullseye /usr/bin/php \
        /usr/share/mediawiki/maintenance/update.php --quiet --quick 2>&1 \
        | sed \
            -e'/cleanupUsersWithNoId.php to fix this situation./d' \
            -e'/^$/d'
    # https://www.mediawiki.org/wiki/Manual:CleanupUsersWithNoId.php
    echo 'Clean-up MediaWiki users with no ID on web-bullseye'
    docker compose exec web-bullseye /usr/bin/php \
        /usr/share/mediawiki/maintenance/cleanupUsersWithNoId.php \
             --quiet --prefix '*'
    echo 'Stopping web-bullseye container'
    docker compose stop web-bullseye
    # https://www.mediawiki.org/wiki/Manual:Update.php
    echo 'Migrating MediaWiki from 1.35.13 (web-bullseye) to 1.43.6 (web)'
    docker compose exec web /usr/bin/php \
        /usr/share/mediawiki/maintenance/run update --quiet --quick
    echo
}


perform_database_maintenance() {
    header 'Perform container database maintenance'
    no_op 'TODO'
    echo
}


perform_content_maintenance() {
    header 'Perform container content maintenance'
    # https://www.mediawiki.org/wiki/Manual:RemoveUnusedAccounts.php
    echo 'Removing unused accounts'
    docker compose exec web /usr/bin/php \
        /usr/share/mediawiki/maintenance/run removeUnusedAccounts --quiet \
        --delete --ignore-touched 0
    # https://www.mediawiki.org/wiki/Manual:cleanupTitles.php
    echo 'Cleaning up page titles'
    docker compose exec web /usr/bin/php \
        /usr/share/mediawiki/maintenance/run cleanupTitles --quiet
    # https://www.mediawiki.org/wiki/Manual:rebuildall.php
    echo 'Rebuilding text index, recent changes, and refreshing links'
    docker compose exec web /usr/bin/php \
        /usr/share/mediawiki/maintenance/run rebuildall --quiet
    echo
}


no_op() {
    # Print no-op message"
    printf "${E90}no-op: %s${E0}\n" "${@}"
}


optimize_tables() {
    header 'Optimize MediaWiki database tables'
    wpcli db optimize --color \
        | sed -e'/Table does not support optimize/d' -e'/^status   : OK/d'
    echo
}


parse_command() {
    if [[ -z "${1}" ]]
    then
        error_exit 'a COMMAND is required'
    elif [[ -n "${2:-}" ]]
    then
        error_exit 'only a single COMMAND is allowed'
    fi
    case "${1:-}" in
        -h*|--h*|h*|'-?'|'--?'|'?') COMMAND=help;;
        info) COMMAND=info;;
        pull) COMMAND=pull;;
        import) COMMAND=import;;
        *) error_exit "invalid COMMAND: ${1}";;
    esac
}


print_key_val() {
    printf "${E97}${E100}%22s${E0} %s\n" "${1}:" "${2}"
}


print_var() {
    print_key_val "${1}" "${!1}"
}


pull_database() {
    # https://www.mediawiki.org/wiki/Manual:Backing_up_a_wiki
    header 'Pull MediaWiki database from legacy production server'
    print_var PROD_SERVER
    print_var PROD_MW_DB
    print_var CACHE_SQL
    # https://mariadb.com/kb/en/mariadb-dump/
    ssh "${PROD_SERVER}" \
        sudo mysqldump --defaults-extra-file=/etc/mysql/debian.cnf \
            --no-tablespaces --single-transaction --skip-lock-tables \
            "${PROD_MW_DB}" \
        > "${CACHE_SQL}.tmp"
    mv "${CACHE_SQL}.tmp" "${CACHE_SQL}"
    du -sh "${CACHE_SQL}"
    echo
}


pull_images() {
    # https://www.mediawiki.org/wiki/Manual:Backing_up_a_wiki
    header 'Pull MediaWiki images files from legacy production server'
    print_var PROD_SERVER
    print_var PROD_IMAGES_DIR
    print_var CACHE_DIR
    # The rsync options below are ordered to match `man rsync`
    rsync \
        --recursive \
        --links \
        --delete \
        --delete-excluded \
        --partial \
        --prune-empty-dirs \
        --times \
        --exclude 'lock_*' \
        --exclude '.htaccess' \
        --stats \
        --human-readable \
        "${PROD_SERVER}:${PROD_IMAGES_DIR}" \
        "${CACHE_IMAGES_DIR}/"
    echo
    du -sh "${CACHE_IMAGES_DIR}"
    echo
}


rsync_version() {
    local _rsync_version
    _rsync_version="$(rsync --version 2>&1 \
        | awk '/version/ {print $3", "$4" "$5" "$6}')"
    RSYNC_PROT_VER=${_rsync_version##* }
    print_key_val 'rsync version' "${_rsync_version}"
    # Check rsync version
    if (( RSYNC_PROT_VER < 31 ))
    then
        _err="rsync protocol version ${RSYNC_PROT_VER} is less than"
        _err="${_err} ${RSYNC_PROT_VER_MIN}--please install via"
        _err="${_err} \`brew install rsync\` (you may need to open a"
        _err="${_err} new terminal to see new the rsync)"
        error_exit "${_err}"
    fi
}


script_setup() {
    local _cache_dir_filesystem _err _rsync_ver _service _var
    if [[ "$(uname)" != 'Darwin' ]]
    then
        error_exit 'only a macOS (Darwin) environment is supported'
    fi

    header "Setup environment: local docker development"
    # Check execution environment
    if [[ "${PWD##*/}" != 'migrate' ]]
    then
        _err='this script must be executed from a clone of the public-wiki'
        _err="${_err} repository (this check requires the current directory"
        _err="${_err} to me named 'migrate')"
        error_exit "${_err}"
    fi
    # Ensure docker daemon is running
    if [[ ! -S /var/run/docker.sock ]]
    then
        error_exit 'docker daemon is not running'
    fi
    # Ensure services are running
    for _service in web web-bullseye db
    do
        if ! docker compose exec "${_service}" true 2>/dev/null
        then
            error_exit "docker service is not running: ${_service}"
        fi
    done

    CACHE_DIR=./cache
    mkdir -p "${CACHE_DIR}"

    DOCKER_MW_IMAGES_DIR="${DOCKER_MW_DIR}/images"
    DOCKER_SQL="/var/migration-cache/${PROD_MW_HOST}_export.sql"
    CACHE_IMAGES_DIR="${CACHE_DIR}/images"
    CACHE_SQL="${CACHE_DIR}/${PROD_MW_HOST}_export.sql"

    print_var COMMAND
    print_key_val "$(sw_vers --productName) version" \
        "$(sw_vers --productVersion)"
    rsync_version
    print_key_val 'Docker version' \
        "$(docker --version | sed -e's/^Docker *version *//')"

    printf "${E30}${E107}%-22s${E0}\n" 'web container'
    print_key_val 'Debian version' \
        "$(docker compose exec web cat /etc/debian_version)"
    print_key_val 'PHP version' \
        "$(docker compose exec web /usr/bin/php --version \
            | awk '/^PHP/ {print $2}')"
    print_key_val 'MediaWiki version' \
        "$(docker compose exec web apt-cache show mediawiki \
            | awk '/^Version:/ {print $2}')"

    printf "${E30}${E107}%-22s${E0}\n" 'web-bullseye container'
    print_key_val 'Debian version' \
        "$(docker compose exec web-bullseye cat /etc/debian_version)"
    print_key_val 'PHP version' \
        "$(docker compose exec web-bullseye /usr/bin/php --version \
            | awk '/^PHP/ {print $2}')"
    print_key_val 'MediaWiki version' \
        "$(docker compose exec web-bullseye apt-cache show mediawiki \
            | awk '/^Version:/ {print $2}')"

    echo
    staff_only_notice
}


show_help() {
    header 'Usage'
    echo "${SCRIPT_NAME} COMMAND"
    echo
    bold 'Commands'
    # help
    echo 'help        print this help message and exit'
    echo 'info        print setup information'
    echo
    # pull
    echo -n 'pull        pull MediaWiki database and images files from'
    echo ' production Bytemark server'
    echo
    # import
    echo -n 'import      import MediaWiki database and images files'
    echo
    exit
}


staff_only_notice() {
    echo -n "${E93}⚠️ This script can only be run by Creative Commons (CC)"
    echo " staff--it requires shell${E0}"
    echo "${E93}   access to the production server${E0}"
    echo
}


success() {
    printf "${E92}Success:${E0} %s\n" "${@}"
}


test_ssh_to_prod() {
    header 'Test SSH connection to production server'
    print_var PROD_SERVER
    if ! ssh "${PROD_SERVER}" true
    then
        error_exit 'unable to connect--verify config and public key'
    else
        success 'connection verified'
        echo
    fi
}


test_mediawiki_installed() {
    if ! docker compose exec web test -f /etc/mediawiki/LocalSettings.php
    then
        error_exit 'web: initial MediaWiki install has not been completed'
    fi
    if ! docker compose exec web-bullseye \
        test -f /etc/mediawiki/LocalSettings.php
    then
        error_exit \
            'web-bullseye: initial MediaWiki install has not been completed'
    fi
}


#### MAIN #####################################################################

cd "${DIR_MIGRATE}"
parse_command "${@:-}"
case "${COMMAND}" in
    # the following are sorted by order of operations then lexicographically
    'help') show_help;;

    'info') script_setup;;

    'pull')
        script_setup
        test_ssh_to_prod
        pull_images
        pull_database
        ;;

    'import')
        script_setup
        test_mediawiki_installed
        danger_confirm
        delete_mediawiki_images
        import_images
        import_database
        migrate_database
        perform_database_maintenance
        #perform_content_maintenance
        #optimize_database
        ;;
esac
