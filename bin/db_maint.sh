#!/bin/bash
set -o errexit
set -o errtrace
set -o nounset

# shellcheck disable=SC2154
trap '_es=${?};
    printf "${0}: line ${LINENO}: \"${BASH_COMMAND}\"";
    printf " exited with a status of ${_es}\n";
    exit ${_es}' ERR

# shellcheck disable=SC2034
DIR_REPO="$(cd -P -- "${0%/*}/.." && pwd -P)"
# https://en.wikipedia.org/wiki/ANSI_escape_code
E0="$(printf "\e[0m")"        # reset
E30="$(printf "\e[30m")"      # foreground: black
E31="$(printf "\e[31m")"      # foreground: red
E92="$(printf "\e[92m")"      # foreground: bright green
E93="$(printf "\e[93m")"      # foreground: bright yellow
E97="$(printf "\e[97m")"      # foreground: bright white
E107="$(printf "\e[107m")"    # background: bright white
SCRIPT_NAME="${0##*/}"
TABLES=

NOTICE_HELP="
${SCRIPT_NAME} [help]

Run maintenance on MySQL database

${E97}Arguments${E0}
help        print this help message and exit
"

#### FUNCTIONS ################################################################

error_exit() {
    # Echo error message and exit with error
    echo -e "${E31}ERROR:${E0} ${*}" 1>&2
    exit 1
}

get_mywiki_tables() {
    local _count
    print_header 'Get MediaWiki tables'
    TABLES="$(docker compose exec db sh -c \
        'echo " SELECT TABLE_NAME
                FROM information_schema.tables \
                WHERE TABLE_SCHEMA=\"my_wiki\";" \
            | /usr/bin/mysql --skip-column-names')"
    _count="$(echo "${TABLES}" | wc -l)"
    _count="${_count##* }"
    echo "${_count} tables identified"
    echo

}

maintenance_1_check() {
    local _table
    print_header 'Check tables'
    for _table in ${TABLES}
    do
        docker compose exec db sh -c \
            "echo 'CHECK TABLE ${_table};' \
                | /usr/bin/mysql --skip-column-names \
                | sed --null-data \
                    -e's/my[^\n]*OK\n/${E92}.${E0}/g' \
                    -e's/my[^\n]*support check\n/${E93}.${E0}/g'"
    done
    echo
    echo
}

maintenance_2_optimize() {
    local _table
    print_header 'Optimize tables'
    for _table in ${TABLES}
    do
        docker compose exec db sh -c \
            "echo 'OPTIMIZE TABLE ${_table}' \
                | /usr/bin/mysql --skip-column-names \
                | sed --null-data \
                    -e's/my[^\n]*analyze instead\n//g' \
                    -e's/my[^\n]*OK\n/${E92}.${E0}/g' \
                    -e's/my[^\n]*support optimize\n/${E93}.${E0}/g'"
    done
    echo
    echo
}

maintenance_3_analyze() {
    local _table
    print_header 'Analyze tables'
    for _table in ${TABLES}
    do
        docker compose exec db sh -c \
            "echo 'ANALYZE TABLE ${_table}' \
                | /usr/bin/mysql --skip-column-names \
                | sed --null-data \
                    -e's/my[^\n]*OK\n/${E92}.${E0}/g' \
                    -e's/my[^\n]*support analyze\n/${E93}.${E0}/g'"
    done
    echo
    echo
}


mysql_disable_redo_log() {
    print_header 'Disable MySQL redo log'
    docker compose exec db sh -c \
        'echo "ALTER INSTANCE DISABLE INNODB REDO_LOG;" \
        | /usr/bin/mysql'
    echo -n 'InnoDB redo logging is disabled. All data could be lost in case'
    echo ' of a server'
    echo 'crash.'
    echo
}

mysql_enable_redo_log() {
    print_header 'Disable MySQL redo log'
    docker compose exec db sh -c \
        'echo "ALTER INSTANCE ENABLE INNODB REDO_LOG;" \
        | /usr/bin/mysql'
    echo -n 'InnoDB redo logging is enabled. Data is now safe and can be'
    echo ' recovered in case of'
    echo 'a server crash.'
    echo
}

print_header() {
    # Print 80 character wide black on white heading
    printf "${E30}${E107}# %-69s$(date '+%T') ${E0}\n" "${@}"
}

verify_docker_service() {
    local _msg
    # Ensure docker daemon is running
    if [[ ! -S /var/run/docker.sock ]]
    then
        error_exit 'docker daemon is not running'
    fi
    # Ensure service is running
    if ! docker compose exec "${CONTAINER}" true 2>/dev/null
    then
        error_exit "docker service '${CONTAINER}' is not running"
    fi
}

#### MAIN #####################################################################

cd "${DIR_REPO}"
case "${1:-maint}" in
    maint)
        get_mywiki_tables
        mysql_disable_redo_log
        maintenance_1_check
        maintenance_2_optimize
        maintenance_3_analyze
        mysql_enable_redo_log
        ;;
    *) echo "${NOTICE_HELP}";;
esac
