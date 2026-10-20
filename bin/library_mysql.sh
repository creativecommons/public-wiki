# Bash library (DON'T execute)
#
# shellcheck shell=bash disable=SC2148
#
# Usage:
#   DIR_REPO="$(cd -P -- "${0%/*}/.." && pwd -P)"
#   source "${DIR_REPO}/bin/library_common.sh"
#   source "${DIR_REPO}/bin/library_mysql.sh"
#
# Analze maintenance is not included because when an InnoDB table is optimized,
# it does a recreate + analyze instead. For details, see:
# https://dev.mysql.com/doc/refman/26.7/en/optimize-table.html#optimize-table-innodb-details

#### FUNCTIONS ################################################################

mysql_get_mywiki_tables() {
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

mysql_maintenance() {
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
    local _op_lower _op_title _op_upper
    _op_title="${1}"
    _op_lower="$(echo "${_op_title}" | tr '[:upper:]' '[:lower:]')"
    _op_upper="$(echo "${_op_title}" | tr '[:lower:]' '[:upper:]')"
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
