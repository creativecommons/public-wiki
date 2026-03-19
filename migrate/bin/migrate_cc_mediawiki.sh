#!/bin/bash
#
# Notes:
# - See NOTICE_ variables below
# - If you modify this file, please re-check it with shellcheck
# - https://www.mediawiki.org/wiki/Manual:ImportImages.php
#   mw_run_web importImages is unnecessary because we are using a database
#   dump. This was verified by running the import (every file found was
#   skipped).
#
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
# The script_setup() function sets the following global variables:
CACHE_SQL=''
CACHE_DIR=''
CACHE_IMAGES_DIR=''
DOCKER_SQL=''
DOCKER_MW_IMAGES_DIR=''
# The command_parse() function sets the following global variables:
COMMAND=''
# The rsync_version() function sets the following global variables:
declare -i RSYNC_PROT_VER=0
NOTICE_CONTAINERS="\
⚠️ This script's import command requires the services in
   REPO/migrate/docker-compose.yml, which includes both web-bullseye (MediaWiki
   1.35.13) and web (MediaWiki 1.43.6). Care should be taken as they share the
   same images Docker volume and database."
NOTICE_STAFF="\
⚠️ This script's pull command can only be run by Creative Commons (CC) team
   members--it requires shell access to the legacy production server."

#### FUNCTIONS ################################################################


add_and_configure_logo() {
    print_header 'Add and configure logo'
    print_var DOCKER_MW_IMAGES_DIR
    echo 'Download logo to container (temporary location)'
    docker compose exec web \
        curl --location --output "${DOCKER_MW_IMAGES_DIR}/cc.svg" --silent \
            'https://mirrors.creativecommons.org/presskit/icons/cc.svg'
    docker compose exec web du -sh "${DOCKER_MW_IMAGES_DIR}/cc.svg"
    echo 'Import logo to WikiMedia'
    mw_run_web importImages --check-userblock --comment='Import CC logo' \
        "${DOCKER_MW_IMAGES_DIR}/cc.svg"
    echo 'Remove logo from container (temporary location)'
    docker compose exec web rm -vf "${DOCKER_MW_IMAGES_DIR}/cc.svg"
}


command_help() {
    print_header 'Usage'
    echo "${SCRIPT_NAME} COMMAND"
    echo
    echo "${E97}Commands${E0}"
    # help
    echo 'help        print this help message and exit'
    echo
    # test
    echo 'info        run tests and print setup information'
    echo
    # pull
    echo -n 'pull        pull MediaWiki database and images files from'
    echo ' production Bytemark'
    echo '            server'
    echo
    # import
    echo 'import      import MediaWiki database and images files'
    echo
}


command_parse() {
    if [[ -z "${1}" ]]
    then
        error_exit 'a COMMAND is required'
    elif [[ -n "${2:-}" ]]
    then
        error_exit 'only a single COMMAND is allowed'
    fi
    case "${1:-}" in
        -h*|--h*|h*|'-?'|'--?'|'?') COMMAND='help';;
        test) COMMAND='test';;
        pull) COMMAND='pull';;
        import) COMMAND='import';;
        *) error_exit "invalid COMMAND: ${1}";;
    esac
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


database_maintenance(){
    local _note _note_one _note_two
    print_header 'Optimize MediaWiki database tables'
    _note='note     :'
    # Check
    _note_one="${_note} The storage engine for the table doesn't support check"
    echo "${E1}Check all databases.${E0} Dicarded notes include:"
    echo "  ${_note_one}"
    docker compose exec db sh -c 'mariadbcheck \
        --password="${MARIADB_ROOT_PASSWORD}" --all-databases --silent \
        --check' 2>&1 | gsed --regexp-extended --null-data \
            -e"s/[^\n]+\n${_note_one}\n//g"
    # Optimize
    _note_one="${_note} Table does not support optimize, doing recreate [+]"
    _note_one="${_note_one} analyze instead"
    _note_two="${_note} The storage engine for the table doesn't support"
    _note_two="${_note_two} optimize"
    echo "${E1}Optimize all databases.${E0} Dicarded notes include:"
    echo "  ${_note_one}"
    echo "  ${_note_two}"
    docker compose exec db sh -c 'mariadbcheck \
        --password="${MARIADB_ROOT_PASSWORD}" --all-databases --silent \
        --optimize' 2>&1 | gsed --regexp-extended --null-data \
            -e"s/[^\n]+\n${_note_one}\n//g" \
            -e"s/[^\n]+\n${_note_two}\n//g"
    # Analyize
    _note_one="${_note} The storage engine for the table doesn't support"
    _note_one="${_note_one} analyze"
    echo "${E1}Analyize all databases.${E0} Dicarded notes include:"
    echo "  ${_note_one}"
    docker compose exec db sh -c 'mariadbcheck \
        --password="${MARIADB_ROOT_PASSWORD}" --all-databases --silent \
        --analyze' 2>&1 | gsed --regexp-extended --null-data \
            -e"s/[^\n]+\n${_note_one}\n//g"
    echo
}


delete_mediawiki_images() {
    local _count
    print_header 'Delete MediaWiki images from container'
    print_var DOCKER_MW_IMAGES_DIR
    echo -n 'Delete contents of images directory:'
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


import_database() {
    print_header 'Import data into container database'
    print_var DOCKER_SQL
    echo 'Import database dump SQL on web-bullseye'
    mw_run_web_bullseye sql.php --quiet "${DOCKER_SQL}"
    echo
}


import_images() {
    print_header 'Import images into container'
    print_var CACHE_IMAGES_DIR
    print_var DOCKER_MW_IMAGES_DIR
    echo 'Copy cache images to docker temp images dir'
    docker compose cp ./cache/images/. "web:${DOCKER_MW_IMAGES_DIR}/"
    echo 'Set ownership of entire images dir to www-data:wwww-data'
    docker compose exec --user root web chown -R www-data:www-data \
        "${DOCKER_MW_IMAGES_DIR}"
    echo
}


migrate_database() {
    print_header 'Migrate container database'
    # https://www.mediawiki.org/wiki/Manual:Update.php
    echo 'Migrate MediaWiki from 1.30.0 (Bytemark) to 1.35.13 (web-bullseye)'
    mw_run_web_bullseye update.php --quiet --quick 2>&1 \
        | sed \
            -e'/cleanupUsersWithNoId.php to fix this situation./d' \
            -e'/^$/d'
    # https://www.mediawiki.org/wiki/Manual:CleanupUsersWithNoId.php
    echo 'Clean-up MediaWiki users with no ID on web-bullseye'
    mw_run_web_bullseye cleanupUsersWithNoId.php --quiet --prefix '*'
    # The above command should be the last one executed on web-bullseye
    echo -n "${E93}Remove mw_run_web_bullseye() function for remaining"
    echo " script run${E0}"
    unset -f mw_run_web_bullseye
    # https://www.mediawiki.org/wiki/Manual:Update.php
    echo 'Migrate MediaWiki from 1.35.13 (web-bullseye) to 1.43.6 (web)'
    mw_run_web update --quiet --quick
    echo
}


mw_maintenance_accounts() {
    print_header 'MediaWiki account maintenance'
    # https://www.mediawiki.org/wiki/Manual:RemoveUnusedAccounts.php
    echo 'Remove unused accounts'
    mw_run_web removeUnusedAccounts --quiet --delete --ignore-touched 0
    echo
}


mw_maintenance_images() {
    local _dir
    print_header 'MediaWiki image maintenance'
    print_var DOCKER_MW_IMAGES_DIR

    # Unneeded as we are using a database dump (already includes image info)
    ## https://www.mediawiki.org/wiki/Manual:ImportImages.php
    #for _dir in {0..9} {a..f}
    #do
    #    echo "Import images: ${DOCKER_MW_IMAGES_DIR}/${_dir}"
    #    mw_run_web importImages --search-recursively --dry \
    #        "${DOCKER_MW_IMAGES_DIR}/${_dir}" 2>&1 \
    #        | grep -v 'exists, skipping$'
    #done
    ## https://www.mediawiki.org/wiki/Manual:RebuildImages.php
    #echo 'Rebuild images'
    #mw_run_web rebuildImages

    # Useless? Provides data that is unactionable.
    ## https://www.mediawiki.org/wiki/Manual:CheckImages.php
    #echo 'Check (verify) images'
    #mw_run_web checkImages

    # Useless? Provides data that is unactionable.
    ## https://www.mediawiki.org/wiki/Manual:FindMissingFiles.php
    #echo 'Find missing files'
    #mw_run_web findMissingFiles

    # https://www.mediawiki.org/wiki/Manual:RefreshImageMetadata.php
    echo 'Refresh image metadata'
    mw_run_web refreshImageMetadata --quiet

    # https://www.mediawiki.org/wiki/Manual:RefreshFileHeaders.php
    echo 'Refresh file headers'
    mw_run_web refreshFileHeaders --quiet

    # https://www.mediawiki.org/wiki/Manual:CleanupUploadStash.php
    echo 'Clean-up upload stash'
    mw_run_web cleanupUploadStash --quiet

    echo
}


mw_maintenance_rebuild() {
    print_header 'MediaWiki rebuild maintenance'
    # Note: rebuildall.php is not used because individual scripts allow more
    # user feedback (more echo statements)

    # https://www.mediawiki.org/wiki/Manual:Rebuildtextindex.php
    echo 'Rebuild text index (rebuild the searchindex table)'
    mw_run_web rebuildtextindex --quiet

    # https://www.mediawiki.org/wiki/Manual:Rebuildrecentchanges.php
    echo 'Rebuild recent changes'
    mw_run_web rebuildrecentchanges --quiet

    # https://www.mediawiki.org/wiki/Manual:RefreshLinks.php
    echo -n 'Refresh links (refill pagelinks, categorylinks, and imagelinks'
    echo ' tables)'
    mw_run_web refreshLinks --quiet

    echo
}


mw_maintenance_titles() {
    print_header 'MediaWiki titles maintenance'
    # https://www.mediawiki.org/wiki/Manual:cleanupTitles.php
    echo 'Clean-up page titles'
    mw_run_web cleanupTitles --quiet
    echo
}


mw_run_web() {
    # https://www.mediawiki.org/wiki/Manual:Maintenance_scripts
    #     Since MediaWiki 1.40, maintenance scripts should be invoked
    #     indirectly through php ./maintenance/run.php. Invoking maintenance
    #     scripts directly will trigger a warning.
    docker compose exec web /usr/bin/php \
        /usr/share/mediawiki/maintenance/run "${@}"
}


mw_run_web_bullseye() {
    # https://www.mediawiki.org/wiki/Manual:Sql.php, for example:
    #     In MediaWiki version MediaWiki 1.39 and earlier, you must invoke
    #     maintenance scripts using php maintenance/scriptName.php instead of
    #     php maintenance/run.php scriptName.
    # shellcheck disable=SC2145
    docker compose exec web-bullseye /usr/bin/php \
        /usr/share/mediawiki/maintenance/"${@}"
}


notice_staff_only() {
    echo "${E93}${NOTICE_STAFF}${E0}"
    echo
}


notice_containers() {
    echo "${E93}${NOTICE_CONTAINERS}${E0}"
    echo
}

prep_sql() {
    print_header 'Prepare MediaWiki SQL'
    print_var CACHE_SQL
    echo '1. Update ENGINE: MyISAM to InnoDB'
    echo '2. Update CHARSET: latin1 to binary'
    # shellcheck disable=SC2016
    echo '3. Update `searchindex` CHARSET to utf8mb4'
    # shellcheck disable=SC2016
    gsed --regexp-extended --null-data \
        -e's/ENGINE=MyISAM/ENGINE=InnoDB/g' \
        -e's/CHARSET=latin1/CHARSET=binary/g' \
        -e's/(FULLTEXT KEY `si_text` \(`si_text`\)\n\) ENGINE=)InnoDB( DEFAULT CHARSET=)binary/\1InnoDB\2utf8mb4/' \
        -i "${CACHE_SQL}"
    echo
}


print_header() {
    # Print 80 character wide black on white heading
    printf "${E30}${E107}# %-69s$(date '+%T') ${E0}\n" "${@}"
}


print_key_val() {
    printf "${E97}${E100}%24s${E0} %s\n" "${1}:" "${2}"
}


print_var() {
    print_key_val "${1}" "${!1}"
}


pull_database() {
    # https://www.mediawiki.org/wiki/Manual:Backing_up_a_wiki
    print_header 'Pull MediaWiki database from legacy production server'
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
    echo 'Back up database export and compress it'
    gzip --force --keep "${CACHE_SQL}"
    du -sh "${CACHE_SQL}.gz"
    echo
}


pull_images() {
    # https://www.mediawiki.org/wiki/Manual:Backing_up_a_wiki
    print_header 'Pull MediaWiki images files from legacy production server'
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
        --exclude 'CVS' \
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

    print_header "Setup environment: local docker development"
    # Check execution environment
    if [[ "${PWD##*/}" != 'migrate' ]]
    then
        _err='this script must be executed from a clone of the public-wiki'
        _err="${_err} repository (this check requires the current directory"
        _err="${_err} to me named 'migrate')"
        error_exit "${_err}"
    fi
    if ! command -v gsed >/dev/null
    then
        # shellcheck disable=SC2016
        error_exit \
             'GNU sed is required. If on macOS install `gnu-sed` via brew.'
    fi

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

    echo
}


success() {
    printf "${E92}Success:${E0} %s\n" "${@}"
}


test_ssh_to_prod() {
    print_header 'Test SSH connection to production server'
    print_var PROD_SERVER
    if ! ssh "${PROD_SERVER}" true
    then
        error_exit 'unable to connect--verify config and public key'
    else
        success 'connection verified'
        echo
    fi
}


verify_docker_services() {
    local _msg _target _service _webs
    _target="${1}"
    case "${_target}" in
        all) _webs='web web-bullseye';;
        minimal) _webs='web';;
    esac
    # Ensure docker daemon is running
    if [[ ! -S /var/run/docker.sock ]]
    then
        error_exit 'docker daemon is not running'
    fi
    # Ensure db service is running
    if ! docker compose exec db true 2>/dev/null
    then
        error_exit 'docker service is not running: db'
    fi
    printf "${E30}${E107}%-24s${E0}\n" ' db container'
    print_key_val 'Debian version' \
        "$(docker compose exec db cat /etc/debian_version)"
    print_key_val 'MariaDB version' \
        "$(docker compose exec db mariadb --version \
            | awk -F',' '{print $1}')"

    # Ensure web services are running
    for _service in ${_webs}
    do
        if ! docker compose exec "${_service}" true 2>/dev/null
        then
            error_exit "docker service is not running: ${_service}"
        fi
        if ! docker compose exec "${_service}" \
            test -f /etc/mediawiki/LocalSettings.php
        then
            _msg="${_service}: initial MediaWiki install has not been"
            _msg="${_msg} completed"
            error_exit "${_msg}"
        fi
        printf "${E30}${E107}%-24s${E0}\n" " ${_service} container"
        print_key_val 'Debian version' \
            "$(docker compose exec "${_service}" cat /etc/debian_version)"
        print_key_val 'PHP version' \
            "$(docker compose exec "${_service}" /usr/bin/php --version \
                | awk '/^PHP/ {print $2}')"
        print_key_val 'MediaWiki version' \
            "$(docker compose exec "${_service}" apt-cache show mediawiki \
                | awk '/^Version:/ {print $2}')"
    done
    echo
}


#### MAIN #####################################################################

cd "${DIR_MIGRATE}"
command_parse "${@:-}"
case "${COMMAND}" in
    # the following are sorted by order of operations then lexicographically
    'help')
        command_help
        ;;

    'pull')
        script_setup
        notice_staff_only
        test_ssh_to_prod
        pull_images
        pull_database
        ;;

    'import')
        script_setup
        verify_docker_services 'all'
        notice_containers
        danger_confirm
        delete_mediawiki_images
        import_images
        prep_sql
        import_database
        migrate_database
        mw_maintenance_accounts
        mw_maintenance_images
        mw_maintenance_titles
        mw_maintenance_rebuild
#broken-prob-requires-valid-accou-t#        add_and_configure_logo
        database_maintenance
        ;;

    'test')
        script_setup
        verify_docker_services 'all'
        notice_staff_only
        notice_containers
        test_ssh_to_prod
        ;;
esac
