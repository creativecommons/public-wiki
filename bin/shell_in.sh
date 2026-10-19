#!/bin/bash
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
E31="$(printf "\e[31m")"      # foreground: red
E97="$(printf "\e[97m")"      # foreground: bright white
# shellcheck disable=SC2034
DIR_REPO="$(cd -P -- "${0%/*}/.." && pwd -P)"
SCRIPT_NAME="${0##*/}"

NOTICE_HELP="
${SCRIPT_NAME} help | CONTAINER

Open an interactive Bash shell in a running container

${E97}Arguments${E0}
help        print this help message and exit
CONTAINER   name of the service in which to open an interactive Bash shell

${E97}Related${E0}
See also \`docker compose exec --help\`
"

#### FUNCTIONS ################################################################

error_exit() {
    # Echo error message and exit with error
    echo -e "${E31}ERROR:${E0} ${*}" 1>&2
    exit 1
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

open_shell_in() {
    docker compose exec "${CONTAINER}" bash -i
}


#### MAIN #####################################################################

cd "${DIR_REPO}"
case "${1:-help}" in
    -*|HELP|help|'?') echo "${NOTICE_HELP}";;
    *)
        CONTAINER="${1}"
        verify_docker_service
        open_shell_in
        ;;
esac
