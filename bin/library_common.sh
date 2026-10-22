# Bash library (DON'T execute)
#
# shellcheck shell=bash disable=SC2034,SC2148
#
# Usage:
#   DIR_REPO="$(cd -P -- "${0%/*}/.." && pwd -P)"
#   source "${DIR_REPO}/bin/library_common.sh"
#
set -o errexit
set -o errtrace
set -o nounset

# shellcheck disable=SC2154
trap '_es=${?};
    printf "${0}: line ${LINENO}: \"${BASH_COMMAND}\"";
    printf " exited with a status of ${_es}\n";
    exit ${_es}' ERR

# https://en.wikipedia.org/wiki/ANSI_escape_code
E0="$(printf "\e[0m")"        # reset
E30="$(printf "\e[30m")"      # foreground: black
E31="$(printf "\e[31m")"      # foreground: red
E36="$(printf "\e[36m")"      # foreground: cyan
E90="$(printf "\e[90m")"      # foreground: bright black (gray)
E92="$(printf "\e[92m")"      # foreground: bright green
E93="$(printf "\e[93m")"      # foreground: bright yellow
E97="$(printf "\e[97m")"      # foreground: bright white
E100="$(printf "\e[100m")"    # background: bright black (gray)
E107="$(printf "\e[107m")"    # background: bright white
SCRIPT_NAME="${0##*/}"

#### FUNCTIONS ################################################################

docker_info_db() {
    print_key_val 'Docker container' "${E97}db${E0}"
    if ! docker compose exec 'db' true 2>/dev/null
    then
        error_exit "Docker 'db' service is not running"
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

docker_info_web() {
    print_key_val 'Docker container' "${E97}web${E0}"
    if ! docker compose exec 'web' true 2>/dev/null
    then
        error_exit "docker 'web' service is not running"
    fi
    print_key_val 'Debian version' \
        "$(docker compose exec 'web' cat /etc/debian_version)"
    print_key_val 'PHP version' \
        "$(docker compose exec 'web' \
            /usr/bin/php --version | awk '/^PHP/ {print $2}')"
    if ! docker compose exec 'web' \
        test -f /etc/mediawiki/LocalSettings.php
    then
        error_exit 'web: initial MediaWiki install has not been completed'
    fi
    print_key_val 'MediaWiki version' \
        "$(docker compose exec 'web' \
            apt-cache show mediawiki | awk '/^Version:/ {print $2}')"
    print_key_val 'MySQL client library' \
        "mariadb-client $(docker compose exec 'web' \
            apt-cache show mariadb-client | awk '/^Version:/ {print $2}')"
    echo
}


docker_verify_daemon() {
    if [[ ! -S /var/run/docker.sock ]]
    then
        error_exit 'Docker daemon is not running'
    fi
}

error_exit() {
    # Echo error message and exit with error
    echo -e "${E31}ERROR:${E0} ${*}" 1>&2
    exit 1
}

print_bright() {
    echo "${E97}${1}${E0}"
}

print_header() {
    # Print 80 character wide black on white heading
    printf "${E30}${E107}# %-69s$(date '+%T') ${E0}\n" "${@}"
}

print_key_val() {
    printf "${E97}${E100}%23s${E0} %s\n" "${1}:" "${2}" | repo_rel_path
}

print_var() {
    print_key_val "${1}" "${!1}"
}

repo_rel_path() {
    sed -e"s|${DIR_REPO}|DIR_REPO|"
}

set_time_format() {
    TIMEFORMAT="${E90}Duration: %3lR${E0}"
}

#### MAIN #####################################################################

cd "${DIR_REPO}" || exit
