#!/bin/bash
# shellcheck disable=SC1091

DIR_REPO="$(cd -P -- "${0%/*}/.." && pwd -P)"
source "${DIR_REPO}/bin/library_common.sh"
source "${DIR_REPO}/bin/library_mysql.sh"

NOTICE_HELP="
${SCRIPT_NAME} [help]

Run maintenance on MySQL MediaWiki tables

${E97}Arguments${E0}
help        print this help message and exit
"

#### FUNCTIONS ################################################################

verify_docker_service() {
    print_header 'Verifying docker service'
    docker_verify_daemon
    docker_info_db
}

#### MAIN #####################################################################

case "${1:-maint}" in
    maint)
        verify_docker_service
        mysql_get_mywiki_tables
        mysql_redo_log 'Disable'
        mysql_maintenance 'Check'
        mysql_maintenance 'Optimize'
        mysql_redo_log 'Enable'
        ;;
    *) echo "${NOTICE_HELP}";;
esac
