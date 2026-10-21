#!/bin/bash
# shellcheck disable=SC2016
set -o errexit
set -o errtrace
set -o nounset

# shellcheck disable=2154
trap '_es=${?};
    printf "${0}: line ${LINENO}: \"${BASH_COMMAND}\"";
    printf " exited with a status of ${_es}\n";
    exit ${_es}' ERR

# https://en.wikipedia.org/wiki/ANSI_escape_code
E0="$(printf "\e[0m")"        # reset
E90="$(printf "\e[90m")"      # foreground: bright black (gray)
E97="$(printf "\e[97m")"      # foreground: bright white

bold() {
    printf "${E97}msmtp: %s${E0} ${E90}%s${E0}\n" "${1}" \
        "$(date --utc '+%F %T.%N %Z')"
}


bold 'Begin configuration'


echo 'msmtp: Configure /etc/mailname'
MAILNAME="${MW_SERVER_URL##*/}"
MAILNAME="${MAILNAME%%:*}"
MAILNAME="${MAILNAME%/}"
if [[ "${MAILNAME}" == 'localhost' ]]
then
    MAILNAME='docker-public-wiki-web'
fi
echo "${MAILNAME}" > /etc/mailname

echo 'msmtp: Configure /etc/aliases'
echo "\
# https://manpages.debian.org/trixie/msmtp/msmtp.1.en.html#aliases
default:    ${DMA_ROOT_ALIAS}
root:       ${DMA_ROOT_ALIAS}
www-data:   ${DMA_ROOT_ALIAS}" > /etc/aliases

echo 'msmtp: Configure log file'
touch /var/log/msmtp.log
chown root:www-data /var/log/msmtp.log
chmod 0664 /var/log/msmtp.log

echo 'msmtp: Configure /etc/msmtprc'
echo "\
# https://manpages.debian.org/trixie/msmtp/msmtp.1.en.html
account smarthost
host ${DMA_SMARTHOST}
port 587
# %M will be replaced by the contents of /etc/mailname
domain %M
auth on
user ${DMA_AUTH_USER}
password ${DMA_AUTH_PASS}
tls on
from ${MW_EMAIL}
set_from_header on
logfile /var/log/msmtp.log
syslog off
aliases /etc/aliases
account default : smarthost" > /etc/msmtprc

bold 'End configuration  '
