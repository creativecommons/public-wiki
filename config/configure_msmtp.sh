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


bold 'Begin msmtp configuration'


echo '  msmtp: Configure /etc/mailname'
MAILNAME="${MW_SERVER_URL##*/}"
MAILNAME="${MAILNAME%%:*}"
MAILNAME="${MAILNAME%/}"
if [[ "${MAILNAME}" == 'localhost' ]]
then
    MAILNAME="docker-public-wiki-${CONTAINER}"
fi
echo "${MAILNAME}" > /etc/mailname

echo '  msmtp: Configuring /etc/aliases'
echo "\
# https://manpages.debian.org/trixie/msmtp/msmtp.1.en.html#aliases
default:    ${DMA_ROOT_ALIAS}
root:       ${DMA_ROOT_ALIAS}
www-data:   ${DMA_ROOT_ALIAS}" > /etc/aliases

echo '  msmtp: Configuring log file'
touch /var/log/msmtp.log
chown root:www-data /var/log/msmtp.log
chmod 0664 /var/log/msmtp.log

echo '  msmtp: Configuring /etc/msmtprc'
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


bold 'End msmtp configuration'
