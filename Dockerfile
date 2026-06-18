# https://docs.docker.com/engine/reference/builder/

# https://hub.docker.com/_/debian
FROM debian:trixie-slim
# NOTE: Occurrences of "NOTE: PHP version", below, where a specific PHP version
#       is required (based on version supported by installed Debian version)

# https://docs.docker.com/build/building/best-practices/#apt-get
# - Resynchronize the package index, update packages, install packages,
#   clean-up, and update CA certificates
# - git is included because MediaWiki says: "Git version control software not
#   found. [...] Note Special:Version will not display commit hashes."
RUN apt-get update --no-allow-insecure-repositories \
    && apt-get dist-upgrade --no-install-recommends --no-install-suggests \
        --yes \
    && apt-get install --no-install-recommends --no-install-suggests --yes \
        apache2 \
        apache2-utils \
        ca-certificates \
        curl \
        git \
        imagemagick \
        less \
        libapache2-mod-php \
        mariadb-client \
        mediawiki \
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
    && apt-get clean \
    && rm --recursive --force /var/lib/apt/lists/* \
    && update-ca-certificates

# Add Apache2 virtualhost configuration
COPY config/web-sites-available /etc/apache2/sites-available/

# Add housekeeping + Apache2 service startup script
COPY config/startupservice.sh /usr/local/sbin/
RUN chmod +x /usr/local/sbin/startupservice.sh
CMD ["/usr/local/sbin/startupservice.sh"]

# Enable Apache modules - NOTE: PHP version
RUN a2enmod headers \
  && a2enmod php8.4 \
  && a2enmod rewrite

# Add MediaWiki configuration script
COPY config/configure_mediawiki.sh /usr/local/sbin/
RUN chmod +x /usr/local/sbin/configure_mediawiki.sh

# Configure PHP - NOTE: PHP version
COPY config/90-local.ini /etc/php/8.4/apache2/conf.d/

# Expose ports for Apache
EXPOSE 80

WORKDIR /var/lib/mediawiki
