#!/bin/bash
# shellcheck disable=SC2016
set -o errexit
set -o nounset

# https://en.wikipedia.org/wiki/ANSI_escape_code
E0="$(printf "\e[0m")"        # reset
E90="$(printf "\e[90m")"      # foreground: bright black (gray)
E97="$(printf "\e[97m")"      # foreground: bright white


bold() {
    printf "${E97}%s${E0}\n" "${@}"
}


bold 'Begin dma (DragonFly Mail Agent) configuration'

echo '  dma: Configuring /etc/aliases'
echo "*:  ${DMA_ROOT_ALIAS}" > /etc/aliases

if grep --quiet "^${DMA_AUTH_USER}" /etc/dma/auth.conf
then
    echo -n "  ${E90}dma: Skipping /etc/dma/auth.conf configuration (already"
    echo " complete)${E0}"
else
    echo '  dma: Configuring /etc/dma/auth.conf'
    echo "${DMA_AUTH_USER}|${DMA_SMARTHOST}:${DMA_AUTH_PASS}" \
        >> /etc/dma/auth.conf
fi

echo '  dma: Configuring /etc/dma/dma.conf'
sed \
    -e"s/^#SMARTHOST\$/SMARTHOST ${DMA_SMARTHOST}/" \
    -e's/^#PORT 25$/PORT 587/' \
    -e's|^#AUTHPATH /etc/dma/auth.conf$|AUTHPATH /etc/dma/auth.conf|' \
    -e's/^#SECURETRANSFER$/SECURETRANSFER/' \
    -e's/^#STARTTLS$/STARTTLS/' \
    -e"s/\(mails as herb@ert\)/\1\nMASQUERADE ${MW_EMAIL}/" \
    -i /etc/dma/dma.conf


bold 'End dma (DragonFly Mail Agent) configuration'
