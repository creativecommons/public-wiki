#!/bin/bash
# shellcheck disable=SC2016,SC2129
set -o errexit
set -o errtrace
set -o nounset

# shellcheck disable=2154
trap '_es=${?};
    printf "${0}: line ${LINENO}: \"${BASH_COMMAND}\"";
    printf " exited with a status of ${_es}\n";
    exit ${_es}' ERR

REMOTEIP_CONF=/etc/apache2/conf-available/remoteip.conf
# https://en.wikipedia.org/wiki/ANSI_escape_code
E0="$(printf "\e[0m")"        # reset
E90="$(printf "\e[90m")"      # foreground: bright black (gray)
E97="$(printf "\e[97m")"      # foreground: bright white


bold() {
    printf "${E97}%s${E0}\n" "${@}"
}


bold 'Begin Apache2 configuration'


echo '  Apache2: Configure RemoteIP (Cloudflare)'
echo '# Restoring original visitor IPs · Cloudflare Support docs
# https://developers.cloudflare.com/support/troubleshooting/restoring-visitor-ips/restoring-original-visitor-ips/
RemoteIPHeader CF-Connecting-IP

# Railway
RemoteIPInternalProxy 100.64.0.0/10

# https://httpd.apache.org/docs/current/mod/mod_log_config.html#formats
LogFormat "%{%F %T}t.%{msec_frac}t %a %u %>s \"%r\" \"%{Location}o\" %O \"%{Referer}i\" \"%{User-Agent}i\"" remoteipcustom' \
    >> "${REMOTEIP_CONF}"
# IPv4
IPV4="$(curl --http2 --raw --silent https://www.cloudflare.com/ips-v4 \
         | sort -V)"
echo '
# https://www.cloudflare.com/ips-v4' \
    >> "${REMOTEIP_CONF}"
for _ip in ${IPV4}
do
    echo "RemoteIPTrustedProxy ${_ip}"
done >> "${REMOTEIP_CONF}"
# IPv6
IPV6="$(curl --http2 --raw --silent https://www.cloudflare.com/ips-v6 \
        | ipv6calc --addr_to_fulluncompressed \
        | sort \
        | ipv6calc --addr_to_compressed)"
echo '
# https://www.cloudflare.com/ips-v6' \
    >> "${REMOTEIP_CONF}"
for _ip in ${IPV6}
do
    echo "RemoteIPTrustedProxy ${_ip}"
done >> "${REMOTEIP_CONF}"
echo >> "${REMOTEIP_CONF}"
echo '# vim: ft=apache:' >> "${REMOTEIP_CONF}"
printf "    ${E90}%s${E0}\n" "$(a2enconf --quiet remoteip)"
printf "    ${E90}%s${E0}\n" "$(a2enmod --quiet remoteip)"

echo '  Apache2: Test configuration'
if apachectl -t &>/dev/null
then
    echo "    ${E90}Syntax OK${E0}"
else
    apachectl -t
fi


bold 'End Apache2 configuration'

# vim: ft=sh
