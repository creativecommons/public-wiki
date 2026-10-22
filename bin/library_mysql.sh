# Bash library (DON'T execute)
#
# shellcheck shell=bash disable=SC2148
#
# Usage:
#   DIR_REPO="$(cd -P -- "${0%/*}/.." && pwd -P)"
#   source "${DIR_REPO}/bin/library_common.sh"
#   source "${DIR_REPO}/bin/library_mysql.sh"

#### FUNCTIONS ################################################################

mysql_get_mywiki_tables() {
    local _count_innodb _count_myisam
    print_header 'Get MediaWiki tables'
    TABLES_INNODB="$(echo '
            SELECT TABLE_NAME
            FROM information_schema.TABLES
            WHERE
                ENGINE = "InnoDB"
                AND TABLE_SCHEMA = "my_wiki";' \
        | docker compose exec --no-tty 'db' mysql --skip-column-names)"
    _count_innodb="$(echo "${TABLES_INNODB}" | wc -l)"
    _count_innodb="${_count_innodb##* }"
    TABLES_MYISAM="$(echo '
            SELECT TABLE_NAME
            FROM information_schema.TABLES
            WHERE
                ENGINE = "MyISAM"
                AND TABLE_SCHEMA = "my_wiki";' \
        | docker compose exec --no-tty 'db' mysql --skip-column-names)"
    _count_myisam="$(echo "${TABLES_MYISAM}" | wc -l)"
    _count_myisam="${_count_myisam##* }"
    TABLES_ALL="$(printf '%s\n%s' "${TABLES_INNODB}" "${TABLES_MYISAM}")"
    print_key_val 'InnoDB tables' "${_count_innodb}"
    print_key_val 'MyISAM tables' "${_count_myisam}"
    echo
}

mysql_maintenance() {
    mysql_maintenance_operation 'Check'
    mysql_maintenance_operation 'Optimize'
    mysql_maintenance_operation 'Analyze'
}

mysql_maintenance_operation() {
    local _header _i _op_lower _op_title _op_upper _option _query \
        _query_innodb _query_myisam _table _tables
    _op_title="${1}"
    _op_lower="$(echo "${_op_title}" | tr '[:upper:]' '[:lower:]')"
    _op_upper="$(echo "${_op_title}" | tr '[:lower:]' '[:upper:]')"
    _option=
    print_header "${_op_title} MediaWiki tables"

    case "${_op_lower}" in
        # https://dev.mysql.com/doc/refman/9.7/en/check-table.html
        check)
            _query_innodb="${_op_upper} TABLE tbl_name"
            _query_myisam="${_query_innodb} EXTENDED"
            ;;
        # https://dev.mysql.com/doc/refman/9.7/en/optimize-table.html
        optimize)
            _query="${_op_upper} TABLE tbl_name"
            _header="InnoDB and MyISAM tables: running"
            _header="${_header} ${E36}${_query}${E0}"
            _tables="${TABLES_ALL}"
            echo -n 'InnoDB tables do not support optimize, recreate +'
            echo ' analyze will be done instead'
            echo
            mysql_maintenance_run "${_header}" "${_query}" "${_tables}"
            ;;
        # https://dev.mysql.com/doc/refman/9.7/en/analyze-table.html
        analyze)
            _query_innodb=
            _query_myisam="${_op_upper} TABLE tbl_name"
            ;;
    esac

    if [[ "${_op_lower}" != 'optimize' ]]
    then
        if [[ -n "${_query_innodb}" ]]
        then
            _header="InnoDB$ tables: running ${E36}${_query_innodb}${E0}"
            _tables="${TABLES_INNODB}"
            mysql_maintenance_run "${_header}" "${_query_innodb}" "${_tables}"
        fi
        if [[ -n "${_query_myisam}" ]]
        then
            _header="MyISAM tables: running ${E36}${_query_myisam}${E0}"
            _tables="${TABLES_MYISAM}"
            mysql_maintenance_run "${_header}" "${_query_myisam}" "${_tables}"
        fi
    fi
}

mysql_maintenance_run() {
    local _header _query _table _tables
    _header="${1}"
    _query="${2}"
    _tables="${3}"
    echo "${_header//tbl_name/${E90}tbl_name${E36}}"
    set_time_format "${_op_lower}"
    time {
        declare -i _i=1
        for _table in ${_tables}
        do
            echo "${_query//tbl_name/${_table}};" \
                | docker compose exec --no-tty 'db' sh -c \
                "mysql --skip-column-names \
                | sed --null-data \
                    -e's/my[^\n]*analyze instead\n[^\n]*OK\n/${E92}.${E0}/g' \
                    -e's/my[^\n]*OK\n/${E92}.${E0}/g' \
                    -e's/my[^\n]*is already up to date\n/${E92}.${E0}/g'"
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
    echo "InnoDB redo logging is ${_op_lower}d."
    case "${_op_lower}" in
        disable)
            echo -n "⚠️  ${E93}All data could be lost in case of a server"
            echo " crash.${E0}"
            ;;
        enable)
            echo -n "🟢 ${E92}Data is now safe and can be recovered in case of"
            echo " a server crash.${E0}"
            ;;
    esac
    echo
}
