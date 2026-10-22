#!/bin/bash
# shellcheck disable=SC1091

DIR_REPO="$(cd -P -- "${0%/*}/.." && pwd -P)"
source "${DIR_REPO}/bin/library_common.sh"
source "${DIR_REPO}/bin/library_mysql.sh"

#### Static variables
# The command_parse() function sets the COMMAND variables:
COMMAND=''
DOCKER_CACHE_EXPORT='/mnt/export'
DOCKER_CACHE_PULL='/mnt/pull'
DOCKER_WEB_ASSETS='/mnt/wiki/var-lib-mediawiki-assets'
DOCKER_WEB_IMAGES='/mnt/wiki/var-lib-mediawiki-images'
NOTICE_TEAM="\
⚠️ This script's pull command can only be run by Creative Commons (CC) team
   members--it requires access to the Railway workspace."
RAILWAY_ENVIRONMENT='production'
RAILWAY_PROJECT='public-wiki'
RAILWAY_SERVICE_MEDIAWIKI='public-wiki'
RAILWAY_SERVICE_MYSQL='MySQL'

#### Dynamic variables
CACHE_EXPORT="${DIR_REPO}/cache/export"
CACHE_EXPORT_ASSETS="${CACHE_EXPORT}/assets"
CACHE_EXPORT_IMAGES="${CACHE_EXPORT}/images"
CACHE_EXPORT_SQL="${CACHE_EXPORT}/db.sql"
CACHE_PULL="${DIR_REPO}/cache/pull"
CACHE_PULL_ASSETS="${CACHE_PULL}/assets"
CACHE_PULL_IMAGES="${CACHE_PULL}/images"
CACHE_PULL_SQL="${CACHE_PULL}/db.sql"
DOCKER_EXPORT_ASSETS="${DOCKER_CACHE_EXPORT}/assets"
DOCKER_EXPORT_IMAGES="${DOCKER_CACHE_EXPORT}/images"
DOCKER_EXPORT_SQL="${DOCKER_CACHE_EXPORT}/db.sql"
DOCKER_PULL_ASSETS="${DOCKER_CACHE_PULL}/assets"
DOCKER_PULL_IMAGES="${DOCKER_CACHE_PULL}/images"
DOCKER_PULL_SQL="${DOCKER_CACHE_PULL}/db.sql"
NOTICE_HELP="
${SCRIPT_NAME} COMMAND

Move MediaWiki data (database SQL and assets & images) in/out of the local
Docker development Docker containers and remote Railway production containers

${E97}Commands${E0}
help    print this help message and exit
info    run tests and print context
pull    pull data from remote containers to local pull cache
import  import data from local pull cache into local containers
export  export data from local containers to local export cache
push    push data from local export cache into remote containers
"
RAILWAY_ASSETS="${DOCKER_WEB_ASSETS}"
RAILWAY_IMAGES="${DOCKER_WEB_IMAGES}"

#### FUNCTIONS ################################################################

command_parse() {
    if [[ -n "${2:-}" ]]
    then
        error_exit 'only a single COMMAND is allowed'
    fi
    case "${1:-}" in
        info)   COMMAND="${1}";;
        pull)   COMMAND="${1}";;
        import) COMMAND="${1}";;
        export) COMMAND="${1}";;
        push)   COMMAND="${1}";;
        *)      COMMAND='help';;
    esac
}

dev_context() {
    print_header 'Development context'
    if [[ "$(uname)" != 'Darwin' ]]
    then
        error_exit 'only a macOS (Darwin) environment is supported'
    fi
    if ! command -v railway >/dev/null
    then
        error_exit 'The Railway CLI is required. Please revisit the README.'
    fi
    if ! command -v rsync >/dev/null
    then
        error_exit 'Rsync is required. Please revisit the README.'
    fi
    print_key_val "$(sw_vers --productName) version" \
        "$(sw_vers --productVersion)"
    print_key_val 'Docker version' \
        "$(docker --version | sed -e's/^Docker *version *//')"
    print_key_val 'Railway version' "$(railway --version)"
    print_key_val 'DIR_REPO' "${DIR_REPO}"
    print_var 'COMMAND'
    echo
}

docker_mw_run() {
    # https://www.mediawiki.org/wiki/Manual:Maintenance_scripts
    #     Since MediaWiki 1.40, maintenance scripts should be invoked
    #     indirectly through php ./maintenance/run.php. Invoking maintenance
    #     scripts directly will trigger a warning.
    docker compose exec --user www-data web /usr/bin/php \
        /usr/share/mediawiki/maintenance/run "${@}" 2>&1 \
        | sed -r -e"s/^(PHP Warning:.+)\$/${E90}\\1${E0}/"
}

files_export() {
    print_header 'Export MediaWiki files to local export cache'
    print_bright '# from local Docker container'
    print_key_val 'Container' "${E97}web${E0}"
    print_var 'DOCKER_WEB_ASSETS'
    print_key_val 'directory size' \
        "$(docker compose exec --env DIR_PATH="${DOCKER_WEB_ASSETS}" 'web' \
            sh -c 'du -sh "${DIR_PATH}"' | awk '{print $1}')"
    print_var 'DOCKER_EXPORT_ASSETS'
    print_var 'DOCKER_WEB_IMAGES'
    print_key_val 'directory size' \
        "$(docker compose exec --env DIR_PATH="${DOCKER_WEB_IMAGES}" 'web' \
            sh -c 'du -sh "${DIR_PATH}"' | awk '{print $1}')"
    print_var 'DOCKER_EXPORT_IMAGES'
    echo
    print_key_val 'Local context' 'export cache'
    print_var 'CACHE_EXPORT_ASSETS'
    mkdir -p "${CACHE_EXPORT_ASSETS}"
    print_var 'CACHE_EXPORT_IMAGES'
    mkdir -p "${CACHE_EXPORT_IMAGES}"
    echo

    #### Assets
    print_bright \
        'Rsync copy assets (remove MediaWiki files not in export cache)' \
        | tr -d '\n'
    set_time_format
    # The rsync options below are ordered to match `man rsync`
    time docker compose exec 'web' \
        rsync \
            --recursive \
            --links \
            --delete \
            --delete-excluded \
            --partial \
            --prune-empty-dirs \
            --times \
            --stats \
            --human-readable \
            "${DOCKER_WEB_ASSETS}/" \
            "${DOCKER_EXPORT_ASSETS}/"
    unset TIMEFORMAT
    print_var 'CACHE_EXPORT_ASSETS'
    print_key_val 'directory size' \
        "$(du -sh "${CACHE_EXPORT_ASSETS}" | awk '{print $1}')"
    echo
    #### Images
    print_bright \
        'Rsync copy images (remove MediaWiki files not in export cache)' \
        | tr -d '\n'
    set_time_format
    # The rsync options below are ordered to match `man rsync`
    time docker compose exec 'web' \
        rsync \
            --recursive \
            --links \
            --delete \
            --delete-excluded \
            --partial \
            --prune-empty-dirs \
            --times \
            --stats \
            --human-readable \
            "${DOCKER_WEB_IMAGES}/" \
            "${DOCKER_EXPORT_IMAGES}/"
    unset TIMEFORMAT
    print_var 'CACHE_EXPORT_IMAGES'
    print_key_val 'directory size' \
        "$(du -sh "${CACHE_EXPORT_IMAGES}" | awk '{print $1}')"
    echo
}

files_import() {
    print_header \
        'Import MediaWiki files to local Docker development container'
    print_bright '# from local pull cache'
    print_key_val 'Local context' 'pull cache'
    print_var 'CACHE_PULL_ASSETS'
    print_key_val 'directory size' \
        "$(du -sh "${CACHE_PULL_ASSETS}" | awk '{print $1}')"
    print_var 'CACHE_PULL_IMAGES'
    print_key_val 'directory size' \
        "$(du -sh "${CACHE_PULL_IMAGES}" | awk '{print $1}')"
    echo
    print_key_val 'Container' "${E97}web${E0}"
    print_var 'DOCKER_PULL_ASSETS'
    print_var 'DOCKER_WEB_ASSETS'
    print_var 'DOCKER_PULL_IMAGES'
    print_var 'DOCKER_WEB_IMAGES'
    echo
    #### Assets
    print_bright \
        'Rsync copy assets (remove MediaWiki files not in pull cache)' \
        | tr -d '\n'
    set_time_format
    # The rsync options below are ordered to match `man rsync`
    time docker compose exec 'web' \
        rsync \
            --recursive \
            --links \
            --delete \
            --delete-excluded \
            --partial \
            --prune-empty-dirs \
            --times \
            --stats \
            --human-readable \
            "${DOCKER_PULL_ASSETS}/" \
            "${DOCKER_WEB_ASSETS}/"
    unset TIMEFORMAT
    echo
    #### Images
    print_bright \
        'Rsync copy images (remove MediaWiki files not in pull cache)' \
        | tr -d '\n'
    set_time_format
    # The rsync options below are ordered to match `man rsync`
    time docker compose exec 'web' \
        rsync \
            --recursive \
            --links \
            --delete \
            --delete-excluded \
            --partial \
            --prune-empty-dirs \
            --times \
            --stats \
            --human-readable \
            "${DOCKER_PULL_IMAGES}/" \
            "${DOCKER_WEB_IMAGES}/"
    unset TIMEFORMAT
    echo 'Set ownership of entire images dir to www-data:wwww-data'
    docker compose exec 'web' chown -R www-data:www-data \
        "${DOCKER_WEB_IMAGES}"
    echo
}

files_pull() {
    # https://www.mediawiki.org/wiki/Manual:Backing_up_a_wiki
    print_header \
        'Pull MediaWiki files from remote Railway production container'
    print_bright '# to local pull cache'
    print_key_val 'Railway service' "${RAILWAY_SERVICE_MEDIAWIKI}"
    print_var 'RAILWAY_ASSETS'
    print_var 'RAILWAY_IMAGES'
    railway link \
        --workspace 'Creative Commons' \
        --project "${RAILWAY_PROJECT}" \
        --environment "${RAILWAY_ENVIRONMENT}" \
        --service "${RAILWAY_SERVICE_MEDIAWIKI}"
    echo
    print_key_val 'Local context' 'pull cache'
    print_var 'CACHE_PULL_ASSETS'
    print_var 'CACHE_PULL_IMAGES'
    mkdir -p "${CACHE_PULL_ASSETS}"
    mkdir -p "${CACHE_PULL_IMAGES}"
    echo
    #### Asssets
    print_bright 'Rsync download assets (remove local files not on remote)' \
        | tr -d '\n'
    set_time_format
    # The rsync options below are ordered to match `man rsync`
    time rsync \
        --recursive \
        --links \
        --rsh="railway ssh --service" \
        --delete \
        --delete-excluded \
        --partial \
        --prune-empty-dirs \
        --times \
        --exclude='.htaccess' \
        --stats \
        --human-readable \
        "${RAILWAY_SERVICE_MEDIAWIKI}:${RAILWAY_ASSETS}/" \
        "${CACHE_PULL_ASSETS}/"
    unset TIMEFORMAT
    print_key_val 'directory size' \
        "$(du -sh "${CACHE_PULL_ASSETS}" | awk '{print $1}')"
    echo
    ##### Images
    print_bright 'Rsync download assets (remove local files not on remote)' \
        | tr -d '\n'
    set_time_format
    # The rsync options below are ordered to match `man rsync`
    time rsync \
        --recursive \
        --links \
        --rsh="railway ssh --service" \
        --delete \
        --delete-excluded \
        --partial \
        --prune-empty-dirs \
        --times \
        --exclude='.htaccess' \
        --stats \
        --human-readable \
        "${RAILWAY_SERVICE_MEDIAWIKI}:${RAILWAY_IMAGES}/" \
        "${CACHE_PULL_IMAGES}/"
    unset TIMEFORMAT
    print_key_val 'directory size' \
        "$(du -sh "${CACHE_PULL_IMAGES}" | awk '{print $1}')"
    echo
}

files_push() {
    # https://www.mediawiki.org/wiki/Manual:Backing_up_a_wiki
    print_header 'Push MediaWiki files to remote Railway production container'
    print_bright '# from local export cache'
    print_key_val 'Local context' 'export cache'
    print_var 'CACHE_EXPORT_ASSETS'
    print_key_val 'directory size' \
        "$(du -sh "${CACHE_EXPORT_ASSETS}" | awk '{print $1}')"
    print_var 'CACHE_EXPORT_IMAGES'
    print_key_val 'directory size' \
        "$(du -sh "${CACHE_EXPORT_IMAGES}" | awk '{print $1}')"
    echo
    print_key_val 'Railway service' "${RAILWAY_SERVICE_MEDIAWIKI}"
    print_var 'RAILWAY_ASSETS'
    print_var 'RAILWAY_IMAGES'
    railway link \
        --workspace 'Creative Commons' \
        --project "${RAILWAY_PROJECT}" \
        --environment "${RAILWAY_ENVIRONMENT}" \
        --service "${RAILWAY_SERVICE_MEDIAWIKI}"
    echo
    #### Asssets
    print_bright 'Rsync upload assets (remove remote files not in local cache)'
    set_time_format
    # The rsync options below are ordered to match `man rsync`
    time rsync \
        --recursive \
        --links \
        --rsh="railway ssh --service" \
        --delete \
        --delete-excluded \
        --partial \
        --prune-empty-dirs \
        --times \
        --stats \
        --human-readable \
        "${CACHE_EXPORT_ASSETS}/" \
        "${RAILWAY_SERVICE_MEDIAWIKI}:${RAILWAY_ASSETS}/"
    unset TIMEFORMAT
    echo
    ##### Images
    print_bright 'Rsync upload images (remove remote files not in local cache)'
    set_time_format
    # The rsync options below are ordered to match `man rsync`
    time rsync \
        --recursive \
        --links \
        --rsh="railway ssh --service" \
        --delete \
        --delete-excluded \
        --partial \
        --prune-empty-dirs \
        --times \
        --stats \
        --human-readable \
        "${CACHE_EXPORT_IMAGES}/" \
        "${RAILWAY_SERVICE_MEDIAWIKI}:${RAILWAY_IMAGES}/"
    unset TIMEFORMAT
    echo
}


mw_maintenance_accounts() {
    local _group _user
    print_header 'MediaWiki account maintenance'

    # https://www.mediawiki.org/wiki/Manual:RemoveUnusedAccounts.php
    echo 'Remove unused accounts'
    docker_mw_run removeUnusedAccounts --delete --ignore-touched 0 2>&1 \
        | grep '^\.\.\.found.*[0-9]\.$' \
        | sed \
            -e"s/^\\.\\.\\.found/${E90}- deleted/" \
            -e"s/\\.$/ unused accounts${E0}/"

    # https://www.mediawiki.org/wiki/Manual:EmptyUserGroup.php
    echo 'Remove all users from legacy groups'
    for _group in affiliate approved community regional staff
    do
        docker_mw_run emptyUserGroup "${_group}" 2>&1 \
            | sed \
                -e'/^Removing users from /d' \
                -e"s/^  ...done! R/- ${_group} ${E90}(r/" \
                -e"s/^  ...nothing to do, /- ${_group} ${E90}(/" \
                -e"s/\\.\$/)${E0}/"
    done

    echo
}

mw_maintenance_images() {
    local _dir
    print_header 'MediaWiki image maintenance'

    ## https://www.mediawiki.org/wiki/Manual:ImportImages.php
    ## https://www.mediawiki.org/wiki/Manual:RebuildImages.php
    # Unneeded as we are using a database dump (already includes image info)

    ## https://www.mediawiki.org/wiki/Manual:CheckImages.php

    ## https://www.mediawiki.org/wiki/Manual:FindMissingFiles.php
    # Useless: provides data that is unactionable.

    # https://www.mediawiki.org/wiki/Manual:RefreshImageMetadata.php
    echo 'Refresh image metadata'
    docker_mw_run refreshImageMetadata --quiet

    # https://www.mediawiki.org/wiki/Manual:RefreshFileHeaders.php
    echo 'Refresh file headers'
    docker_mw_run refreshFileHeaders --quiet

    # https://www.mediawiki.org/wiki/Manual:CleanupUploadStash.php
    echo 'Clean-up upload stash'
    docker_mw_run cleanupUploadStash --quiet

    echo
}

mw_maintenance_rebuild() {
    print_header 'MediaWiki rebuild maintenance'
    # Note: rebuildall.php is not used because individual scripts allow more
    # user feedback (more echo statements)

    # https://www.mediawiki.org/wiki/Manual:Rebuildtextindex.php
    echo 'Rebuild text index (rebuild the searchindex table)'
    docker_mw_run rebuildtextindex --quiet

    # https://www.mediawiki.org/wiki/Manual:Rebuildrecentchanges.php
    echo 'Rebuild recent changes'
    docker_mw_run rebuildrecentchanges --quiet

    # https://www.mediawiki.org/wiki/Manual:RefreshLinks.php
    echo -n 'Refresh links (refill pagelinks, categorylinks, and imagelinks'
    echo ' tables)'
    docker_mw_run refreshLinks --quiet

    echo
}

mw_maintenance_titles() {
    print_header 'MediaWiki titles maintenance'
    # https://www.mediawiki.org/wiki/Manual:cleanupTitles.php
    echo 'Clean-up page titles'
    docker_mw_run cleanupTitles --quiet
    echo
}

notice_staff_only() {
    echo "${E93}${NOTICE_TEAM}${E0}"
    echo
}

railway_auth() {
    print_header 'Verify Railway authentication and SSH'
    echo 'Reading Railway Project Token'
    if [[ ! -f .railway_token ]]
    then
        error_exit 'The .railway_token file does not exist.'
    fi
    # shellcheck disable=SC1091
    source .railway_token
    if [[ -z "${RAILWAY_TOKEN}" ]]
    then
        error_exit 'The RAILWAY_TOKEN variable is empty.'
    fi
    echo 'Authenticating to Railway'
    railway whoami
    echo
}

railway_mysql_auth() {
    print_header \
        'Add authentication file to production Railway MySQL container'
    print_key_val 'Railway service' "${RAILWAY_SERVICE_MYSQL}"
    railway link \
        --workspace 'Creative Commons' \
        --project "${RAILWAY_PROJECT}" \
        --environment "${RAILWAY_ENVIRONMENT}" \
        --service "${RAILWAY_SERVICE_MYSQL}"
    # shellcheck disable=SC2016
    railway ssh --service "${RAILWAY_SERVICE_MYSQL}" \
        'if [[ ! -f /root/.my.cnf ]]
        then
            echo -e "[client]\npassword = ${MYSQL_ROOT_PASSWORD}" \
                > /root/.my.cnf; \
            chmod 0400 /root/.my.cnf
        fi'
    echo
}

sql_export() {
    # https://www.mediawiki.org/wiki/Manual:Backing_up_a_wiki
    print_header 'Export MediaWiki database to local export cache'
    print_bright '# from local Docker container'
    print_key_val 'Container' "${E97}db${E0}"
    print_var 'DOCKER_EXPORT_SQL'
    echo
    print_key_val 'Local context' 'export cache'
    print_var 'CACHE_EXPORT_SQL'
    echo
    print_bright 'Dump database to local export cache sql file'
    echo '(overwrite existing file)'
    set_time_format
    # https://dev.mysql.com/doc/refman/9.7/en/mysqldump.html
    # Options set in /root/.my.cnf in db container
    docker compose exec --env DOCKER_EXPORT_SQL="${DOCKER_EXPORT_SQL}" db \
        sh -c 'mysqldump "${MYSQL_DATABASE}" \
                > "${DOCKER_EXPORT_SQL}.tmp"'
    unset TIMEFORMAT
    mv "${CACHE_EXPORT_SQL}.tmp" "${CACHE_EXPORT_SQL}"
    print_key_val 'sql file size' \
        "$(du -sh "${CACHE_EXPORT_SQL}" | awk '{print $1}')"
    echo
    echo 'Create compressed copy of database dump sql file'
    set_time_format
    time gzip --force --keep "${CACHE_EXPORT_SQL}"
    unset TIMEFORMAT
    print_key_val 'compressed file size' \
        "$(du -sh "${CACHE_EXPORT_SQL}.gz" | awk '{print $1}')"
    echo
}

sql_import() {
    print_header \
        'Import MediaWiki sql dump to local Docker development container'
    print_bright '# from local pull cache'
    print_key_val 'Local context' 'pull cache'
    print_var 'CACHE_PULL_SQL'
    print_key_val 'sql file size' \
        "$(du -sh "${CACHE_PULL_SQL}" | awk '{print $1}')"
    echo
    print_key_val 'Container' "${E97}db${E0}"
    print_var 'DOCKER_PULL_SQL'
    echo
    echo 'Disable autocommit'
    docker compose exec 'db' sh -c 'echo "SET autocommit=0;" | mysql'
    echo 'Import database dump SQL file from local pull cache'
    set_time_format
    time docker compose exec --env DOCKER_PULL_SQL="${DOCKER_PULL_SQL}" 'db' \
        sh -c 'mysql < "${DOCKER_PULL_SQL}"'
    unset TIMEFORMAT
    echo 'Commit the current transaction'
    docker compose exec 'db' sh -c 'echo "COMMIT;" | mysql'
    echo 'Enable autocommit'
    docker compose exec 'db' sh -c 'echo "SET autocommit=1;" | mysql'
    echo
}

sql_pull() {
    # https://www.mediawiki.org/wiki/Manual:Backing_up_a_wiki
    print_header 'Pull MediaWiki database to local pull cache'
    print_bright '# from remote Railway production container'
    print_key_val 'Railway service' "${RAILWAY_SERVICE_MYSQL}"
    railway link \
        --workspace 'Creative Commons' \
        --project "${RAILWAY_PROJECT}" \
        --environment "${RAILWAY_ENVIRONMENT}" \
        --service "${RAILWAY_SERVICE_MYSQL}"
    echo
    print_key_val 'Local context' 'pull cache'
    print_var 'CACHE_PULL_SQL'
    echo
    print_bright 'Dump database to local pull cache sql file'
    echo '(overwrite existing file)'
    set_time_format
    # https://dev.mysql.com/doc/refman/9.7/en/mysqldump.html
    # shellcheck disable=SC2016
    time railway ssh --service "${RAILWAY_SERVICE_MYSQL}" \
        'mysqldump \
            --no-tablespaces \
            --set-gtid-purged=OFF \
            --single-transaction \
            --skip-lock-tables \
            "${MYSQL_DATABASE}"' \
        > "${CACHE_PULL_SQL}.tmp"
    unset TIMEFORMAT
    mv "${CACHE_PULL_SQL}.tmp" "${CACHE_PULL_SQL}"
    print_key_val 'sql file size' \
        "$(du -sh "${CACHE_PULL_SQL}" | awk '{print $1}')"
    echo
    echo 'Create compressed copy of database dump sql file'
    set_time_format
    time gzip --force --keep "${CACHE_PULL_SQL}"
    unset TIMEFORMAT
    print_key_val 'compressed file size' \
        "$(du -sh "${CACHE_PULL_SQL}.gz" | awk '{print $1}')"
    echo
}

sql_push() {
    # https://www.mediawiki.org/wiki/Manual:Backing_up_a_wiki
    print_header \
        'Push MediaWiki database to remote Railway production container'
    print_bright '# from local export cache'
    print_key_val 'Local context' 'pull cache'
    print_var 'CACHE_EXPORT_SQL'
    print_key_val 'sql file size' \
        "$(du -sh "${CACHE_EXPORT_SQL}" | awk '{print $1}')"
    echo
    print_key_val 'Railway service' "${RAILWAY_SERVICE_MYSQL}"
    railway link \
        --workspace 'Creative Commons' \
        --project "${RAILWAY_PROJECT}" \
        --environment "${RAILWAY_ENVIRONMENT}" \
        --service "${RAILWAY_SERVICE_MYSQL}"
    echo
    echo 'Import database dump SQL file from local pull cache'
    set_time_format
    time {
        railway ssh --service "${RAILWAY_SERVICE_MYSQL}" \
            'echo "ALTER INSTANCE DISABLE INNODB REDO_LOG;" | mysql'
        # shellcheck disable=SC2016
        railway ssh --service "${RAILWAY_SERVICE_MYSQL}" \
            'mysql "${MYSQL_DATABASE}"' < "${CACHE_EXPORT_SQL}"
        railway ssh --service "${RAILWAY_SERVICE_MYSQL}" \
            'echo "ALTER INSTANCE ENABLE INNODB REDO_LOG;" | mysql'
    }
    unset TIMEFORMAT
    echo
}

verify_docker_services() {
    print_header 'Verify Docker services'
    docker_verify_daemon
    docker_info_db
    docker_info_web
}

#### MAIN #####################################################################

command_parse "${@:-}"
case "${COMMAND}" in
    # the following are sorted according to a local data edit workflow
    'help') echo "${NOTICE_HELP}";;
    'info')
        dev_context
        notice_staff_only
        verify_docker_services
        ;;
    'pull')
        dev_context
        notice_staff_only
        railway_auth
        files_pull
        railway_mysql_auth
        sql_pull
        ;;
    'import')
        dev_context
        verify_docker_services
        files_import
        mysql_redo_log 'Disable'
        sql_import
        mw_maintenance_accounts
        mw_maintenance_images
        mw_maintenance_titles
        mw_maintenance_rebuild
        mysql_get_mywiki_tables
        mysql_maintenance
        mysql_redo_log 'Enable'
        ;;
    'export')
        dev_context
        verify_docker_services
        files_export
        mysql_get_mywiki_tables
        mysql_maintenance
        sql_export
        ;;
    'push')
        dev_context
        notice_staff_only
        railway_auth
        files_push
        railway_mysql_auth
        sql_push
esac
