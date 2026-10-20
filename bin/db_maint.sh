#!/bin/bash
# shellcheck disable=SC1091

DIR_REPO="$(cd -P -- "${0%/*}/.." && pwd -P)"
source "${DIR_REPO}/bin/library_common.sh"
source "${DIR_REPO}/bin/library_mysql.sh"

NOTICE_HELP="
${SCRIPT_NAME} [help]

Run maintenance on MySQL database

${E97}Arguments${E0}
help        print this help message and exit
"

#### FUNCTIONS ################################################################

verify_docker_service() {
    print_header 'Verifying docker service'
    # Ensure docker daemon is running
    if [[ ! -S /var/run/docker.sock ]]
    then
        error_exit 'docker daemon is not running'
    fi
    print_key_val 'Container' "${E97}db${E0}"
    # Ensure service is running
    if ! docker compose exec 'db' true 2>/dev/null
    then
        error_exit "docker service 'db' is not running"
    fi
    print_key_val 'OS version' \
        "$(docker compose exec 'db' cat /etc/oracle-release)"
    print_key_val 'MySQL version' \
        "$(docker compose exec 'db' mysql --version \
            | sed -r \
                -e's/^mysql  Ver //' \
                -e"s/ [(]/\n${E100}                       ${E0} (/")"
    echo
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
