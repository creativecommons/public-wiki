# https://docs.docker.com/engine/reference/builder/

# https://hub.docker.com/_/mysql/
FROM mysql

# Add MySQL client configuration
ARG MYSQL_DATABASE
COPY config/my.cnf /root/.my.cnf
RUN --mount=type=secret,id=MYSQL_ROOT_PASSWORD,env=MYSQL_ROOT_PASSWORD \
    sed \
        -e"s/REPlACEPASSWORD/${MYSQL_ROOT_PASSWORD}/" \
        -e"s/REPLACEDATABASE/${MYSQL_DATABASE}/" \
        -i /root/.my.cnf
