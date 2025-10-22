#!/bin/bash
set -o errexit
set -o nounset

# https://en.wikipedia.org/wiki/ANSI_escape_code
E0="$(printf "\e[0m")"        # reset
E1="$(printf "\e[1m")"        # bold

/sbin/apache2ctl -v

DB_HOST=${WIKI_DB_HOST:-wiki-db}
DB_PORT=${WIKI_DB_PORT:-3306}

echo "$Waiting for database at ${DB_HOST}:${DB_PORT}..."

# Note proper syntax for /dev/tcp — no colon between host and port
while ! (echo > /dev/tcp/${DB_HOST}/${DB_PORT}) >/dev/null 2>&1; do
  echo "Database not reachable yet. Retrying in 1s..."
  sleep 1
done

echo 'Database is up!'

# Start Apache in the foreground
echo "${E1}Starting apache2 webserver: http://localhost:8080/${E0}"
/sbin/apache2ctl -D FOREGROUND -k start
