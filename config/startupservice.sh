#!/bin/bash
set -o errexit
set -o nounset

# https://en.wikipedia.org/wiki/ANSI_escape_code
E0="$(printf "\e[0m")"        # reset
E1="$(printf "\e[1m")"        # bold

/sbin/apache2ctl -v

DB_HOST=${WIKI_DB_HOST:-wiki-db}
DB_PORT=${WIKI_DB_PORT:-3306}

echo "${E1}Waiting for database at ${DB_HOST}:${DB_PORT}...${E0}"

# Proper syntax for /dev/tcp — NOTE: no colon between host and port
while ! (echo > /dev/tcp/${DB_HOST}/${DB_PORT}) >/dev/null 2>&1; do
  echo "Database not reachable yet. Retrying in 1s..."
  sleep 1
done

echo "${E1}Database is up! Starting apache2 webserver ${E0}"

# Start Apache in the foreground
/sbin/apache2ctl -D FOREGROUND -k start
