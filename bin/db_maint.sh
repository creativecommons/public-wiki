#!/bin/bash
#
# Analze maintenance is not included because when an InnoDB table is optimized,
# it does a recreate + analyze instead. For details, see:
# https://dev.mysql.com/doc/refman/26.7/en/optimize-table.html#optimize-table-innodb-details
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
E100="$(printf "\e[100m")"    # background: bright black (gray)
E107="$(printf "\e[107m")"    # background: bright white
FROM_PARENT_SCRIPT=${FROM_PARENT_SCRIPT:-0}
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
    TABLES="$(docker compose exec 'db' sh -c \
        'echo " SELECT TABLE_NAME
                FROM information_schema.tables \
                WHERE TABLE_SCHEMA=\"my_wiki\";" \
            | /usr/bin/mysql --skip-column-names')"
    _count="$(echo "${TABLES}" | wc -l)"
    _count="${_count##* }"
    print_key_val 'Table count' "${_count}"
    echo

}

maintenance() {
    # https://dev.mysql.com/doc/refman/26.7/en/optimize-table.html
    local _i _op_lower _op_title _op_upper
    _op_title="${1}"
    _op_lower="$(echo "${_op_title}" | tr '[:upper:]' '[:lower:]')"
    _op_upper="$(echo "${_op_title}" | tr '[:lower:]' '[:upper:]')"
    local _table
    print_header "${_op_title} MediaWiki tables"

    print_bright 'Key'
    case "${_op_lower}" in
        check)
            echo "${E92}.${E0} status OK"
            TIMEFORMAT="${E97}${E100}        check duration:${E0} %3lR"
            ;;
        optimize)
            echo -n "${E92}.${E0} status OK (table does not support optimize,"
            echo ' doing recreate + analyze instead)'
            TIMEFORMAT="${E97}${E100}     optimize duration:${E0} %3lR"
            ;;
    esac
    echo -n "${E93}_${E0} The storage engine for the table doesn't support"
    echo " ${_op_lower}"
    echo

    print_bright "Running ${_op_upper} TABLE on all MediaWiki tables"
    time {
        declare -i _i=1
        for _table in ${TABLES}
        do
            docker compose exec 'db' sh -c \
                "echo '${_op_upper} TABLE ${_table};' \
                | /usr/bin/mysql --skip-column-names \
                | sed --null-data \
                    -e's/my[^\n]*analyze instead\n[^\n]*OK\n/${E92}.${E0}/g' \
                    -e's/my[^\n]*OK\n/${E92}.${E0}/g' \
                    -e's/my[^\n]*support ${_op_lower}\n/${E93}_${E0}/g'"
            if (( _i < 80 ))
            then
                (( _i = _i + 1 ))
            else
                echo
                (( _i = 0 ))
            fi
        done
        echo
    }
    unset TIMEFORMAT
    echo
}

mysql_redo_log() {
    (( FROM_PARENT_SCRIPT == 0 )) || return 0
    local _op_lower _op_title _op_upper
    _op_title="${1}"
    _op_lower="$(echo "${_op_title}" | tr '[:upper:]' '[:lower:]')"
    _op_upper="$(echo "${_op_title}" | tr '[:lower:]' '[:upper:]')"
    (( FROM_PARENT_SCRIPT == 0 )) || return 0
    print_header "${_op_title} MySQL redo log"
    docker compose exec --env OPERATION="${_op_upper}" 'db' \
        sh -c 'echo "ALTER INSTANCE ${OPERATION} INNODB REDO_LOG;" | mysql'
    echo -n "InnoDB redo logging is ${_op_lower}d."
    case "${_op_lower}" in
        disable)
            echo ' All data could be lost in case of a server'
            echo 'crash.'
            ;;
        enable)
            echo ' Data is now safe and can be recovered in case of'
            echo 'a server crash.'
            ;;
    esac
    echo
}

print_bright() {
    echo "${E97}${1}${E0}"
}

print_header() {
    # Print 80 character wide black on white heading
    printf "${E30}${E107}# %-69s$(date '+%T') ${E0}\n" "${@}"
}

print_key_val() {
    # Although 23 characters is excessive for the labels in this script, it is
    # also called by bin/move_
    printf "${E97}${E100}%23s${E0} %s\n" "${1}:" "${2}"
}

print_var() {
    print_key_val "${1}" "${!1}"
}

verify_docker_service() {
    (( FROM_PARENT_SCRIPT == 0 )) || return 0
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

cd "${DIR_REPO}"
case "${1:-maint}" in
    maint)
        verify_docker_service
        get_mywiki_tables
        mysql_redo_log 'Disable'
        maintenance 'Check'
        maintenance 'Optimize'
        mysql_redo_log 'Enable'
        ;;
    *) echo "${NOTICE_HELP}";;
esac
