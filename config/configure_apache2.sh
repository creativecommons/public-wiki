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

append() {
    echo "${@}" >> "${REMOTEIP_CONF}"
}

bold() {
    printf "${E97}apache2: %s${E0} ${E90}%s${E0}\n" "${1}" \
        "$(date --utc '+%F %T.%N %Z')"
}


bold 'Begin Apache2 web server configuration'


case "${CONTAINER_ENV}" in
    dev)
        PREFIX='#-'
        NOTE="apache2: [dev disabled]${E90}"
        ;;
    prod)
        PREFIX='';
        NOTE='apache2:';;
esac

append "# https://httpd.apache.org/docs/current/mod/mod_log_config.html#formats
LogFormat \"%{%F %T}t.%{msec_frac}t %a %u %>s \\\"%r\\\" \\\"%{Location}o\\\" %O \
\\\"%{Referer}i\\\" \\\"%{User-Agent}i\\\"\" remoteipcustom\
"

append
if [[ -n "${PREFIX}" ]]
then
    append '# Production configuration disabled in development'
fi
echo "${NOTE} Configure Railway (RemoteIPInternalProxy)${E0}"
append "\
${PREFIX}# Railway
${PREFIX}RemoteIPInternalProxy 100.64.0.0/10\
"

echo "${NOTE} Configure Cloudflare (RemoteIPHeader, RemoteIPTrustedProxy)${E0}"
append "${PREFIX}
${PREFIX}# Cloudflare
${PREFIX}# Restoring original visitor IPs · Cloudflare Support docs
${PREFIX}# https://developers.cloudflare.com/support/troubleshooting/\
restoring-visitor-ips/restoring-original-visitor-ips/
${PREFIX}RemoteIPHeader CF-Connecting-IP\
"

# IPv4
append "${PREFIX}"
IPV4="$(curl --http2 --raw --silent https://www.cloudflare.com/ips-v4 \
         | sort -V)"
append "${PREFIX}# https://www.cloudflare.com/ips-v4"
for _ip in ${IPV4}
do
    append "${PREFIX}RemoteIPTrustedProxy ${_ip}"
done

# IPv6
append "${PREFIX}"
IPV6="$(curl --http2 --raw --silent https://www.cloudflare.com/ips-v6 \
        | ipv6calc --addr_to_fulluncompressed \
        | sort \
        | ipv6calc --addr_to_compressed)"
append "${PREFIX}# https://www.cloudflare.com/ips-v6"
for _ip in ${IPV6}
do
    append "${PREFIX}RemoteIPTrustedProxy ${_ip}"
done

append
append '# vim: ft=apache:'

printf "${E90}apache2: %s${E0}\n" "$(a2enconf --quiet remoteip)"
printf "${E90}apache2: %s${E0}\n" "$(a2enmod --quiet remoteip)"


if apachectl -t &>/dev/null
then
    echo 'apache2: Configuration test: Syntax OK'
else
    echo 'apache2: Configuration test errors:'
    apachectl -t
fi


bold 'End Apache2 web server configuration  '

# vim: ft=sh
