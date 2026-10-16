#!/bin/bash
# shellcheck disable=SC2016
set -o errexit
set -o nounset

# https://en.wikipedia.org/wiki/ANSI_escape_code
E0="$(printf "\e[0m")"        # reset
E97="$(printf "\e[97m")"      # foreground: bright white

bold() {
    printf "${E97}%s${E0}\n" "${@}"
}


bold 'Begin misc (miscellaneous) configuration'


echo '  misc: Configure mail name'
MAILNAME="${MW_SERVER_URL##*/}"
MAILNAME="${MAILNAME%%:*}"
MAILNAME="${MAILNAME%/}"
if [[ "${MAILNAME}" == 'localhost' ]]
then
    MAILNAME="docker-public-wiki-${CONTAINER}"
fi
echo "${MAILNAME}" > /etc/mailname


bold 'End misc (miscellaneous) configuration'
