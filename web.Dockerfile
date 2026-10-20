# https://docs.docker.com/engine/reference/builder/

# https://hub.docker.com/_/debian
FROM debian:trixie-slim
# NOTE: Occurrences of "NOTE: PHP version", below, where a specific PHP version
#       is required (based on version supported by installed Debian version)

LABEL org.opencontainers.image.description="CC Public Wiki web container"
LABEL org.opencontainers.image.licenses=MIT
LABEL org.opencontainers.image.source=https://github.com/creativecommons/public-wiki

# https://docs.docker.com/build/building/best-practices/#apt-get
# - Resynchronize the package index, update packages, install packages,
#   clean-up, and update CA certificates
# - git is included because MediaWiki says: "Git version control software not
#   found. [...] Note Special:Version will not display commit hashes."
RUN set -o errexit -o nounset \
    && DEBIAN_FRONTEND=noninteractive apt-get update \
        --no-allow-insecure-repositories --quiet \
    && DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade \
        --no-install-recommends --no-install-suggests --quiet --yes \
    && DEBIAN_FRONTEND=noninteractive apt-get install \
        --no-install-recommends --no-install-suggests --quiet --yes \
        apache2 \
        apache2-utils \
        ca-certificates \
        curl \
        git \
        imagemagick \
        ipv6calc \
        less \
        libapache2-mod-php \
        mariadb-client \
        mediawiki \
        msmtp-mta \
        php \
        php-apcu \
        php-cli \
        php-common \
        php-curl \
        php-gd \
        php-imagick \
        php-intl \
        php-mbstring \
        php-mysql \
        php-xml \
        php-zip \
        rsync \
        unzip \
        vim \
    && DEBIAN_FRONTEND=noninteractive apt-get clean --quiet \
    && rm --recursive --force /var/lib/apt/lists/* \
    && update-ca-certificates

# Copy startup and configuration scripts and make executable
COPY \
    config/configure_apache2.sh \
    config/configure_mediawiki.sh \
    config/configure_mount.sh \
    config/configure_msmtp.sh \
    config/startupservice.sh \
    /usr/local/sbin/
RUN chmod +x \
    /usr/local/sbin/configure_apache2.sh \
    /usr/local/sbin/configure_mediawiki.sh \
    /usr/local/sbin/configure_mount.sh \
    /usr/local/sbin/configure_msmtp.sh \
    /usr/local/sbin/startupservice.sh

# Set startup script
CMD ["/usr/local/sbin/startupservice.sh"]

# Add Apache2 virtualhost configuration
COPY config/000-default.conf /etc/apache2/sites-available/000-default.conf

# Enable Apache modules - NOTE: PHP version
RUN set -o errexit -o nounset \
  && a2enmod --quiet headers \
  && a2enmod --quiet php8.4 \
  && a2enmod --quiet rewrite

# Configure PHP - NOTE: PHP version
COPY config/90-local.ini /etc/php/8.4/apache2/conf.d/

# Expose ports for Apache
EXPOSE 80

WORKDIR /var/lib/mediawiki
