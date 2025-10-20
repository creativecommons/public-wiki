#!/bin/bash
set -o errexit
set -o nounset

# https://en.wikipedia.org/wiki/ANSI_escape_code
E0="$(printf "\e[0m")"        # reset
E1="$(printf "\e[1m")"        # bold

/sbin/apache2ctl -v

# Check for required environment variables (optional safety)
: "${MW_DB_HOST:?Database host not set}"
: "${MW_DB_PORT:=3306}"

echo "${E1}Waiting for database at ${MW_DB_HOST}:${MW_DB_PORT} to become available...${E0}"

# Wait until DB is ready (same logic as the Django example)
while ! exec 6<>/dev/tcp/${MW_DB_HOST}/${MW_DB_PORT}; do
    echo "Database not reachable yet. Retrying in 2s..."
    sleep 2
done

echo "${E1}Database is available. Starting Apache...${E0}"

# Start Apache in the foreground
/sbin/apache2ctl -D FOREGROUND -k start
