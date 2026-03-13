# https://docs.docker.com/engine/reference/builder/

# https://hub.docker.com/_/debian
FROM debian:bookworm-slim
# NOTE: There are a few PHP version numbers that are specific to the Debian
#       version installed. See "NOTE: PHP version"

# Configure apt not to prompt during docker build
# Accept MediaWiki version from docker-compose.yml
ARG DEBIAN_FRONTEND=noninteractive MW_VERSION

# Configure apt to avoid installing recommended and suggested packages
RUN apt-config dump \
  | grep --extended-regexp '^APT::Install-(Recommends|Suggests)' \
  | sed -e 's/1/0/' \
  | tee /etc/apt/apt.conf.d/99no-recommends-no-suggests

# https://docs.docker.com/build/building/best-practices/#apt-get
# - Resynchronize the package index, update packagse, install packages,
#   clean-up, and update CA certificates
# - git is included because MediaWiki says: "Git version control software not
#   found. [...] Note Special:Version will not display commit hashes."
RUN apt-get update \
    && apt-get dist-upgrade --yes --no-install-recommends \
    && apt-get install --yes --no-install-recommends \
        apache2 \
        apache2-utils \
        ca-certificates \
        curl \
        git \
        imagemagick \
        less \
        libapache2-mod-php \
        mariadb-client \
        php-imagick \
        php \
        php-cli \
        php-common \
        php-curl \
        php-gd \
        php-intl \
        php-mbstring \
        php-mysql \
        php-xml \
        php-zip \
        sudo \
        unzip \
        vim \
    && apt-get clean \
    && rm --recursive --force /var/lib/apt/lists/* \
    && update-ca-certificates

# Add Apache2's www-data user to sudo group and enable passwordless startup
RUN adduser www-data sudo
COPY config/www-data_startupservice /etc/sudoers.d/www-data_startupservice

# Add Apache2 service startup script
COPY config/startupservice.sh /startupservice.sh
RUN chmod +x /startupservice.sh
CMD ["sudo", "--preserve-env", "/startupservice.sh"]

# Expose ports for Apache
EXPOSE 80

# Enable Apache modules - NOTE: PHP version
RUN a2enmod headers \
  && a2enmod php8.2 \
  && a2enmod rewrite

# configure PHP - NOTE: PHP version
COPY config/90-local.ini /etc/php/8.2/apache2/conf.d/

# Install Composer
# https://getcomposer.org/doc/00-intro.md#installation-linux-unix-macos
RUN curl --fail --location --show-error --silent \
        'https://getcomposer.org/installer' \
    | php -- --install-dir=/usr/local/bin --filename=composer

# Create directories and assign permissions
RUN mkdir --parents /var/www/.composer /var/www/wiki/images \
    && chown --recursive www-data:www-data /var/www/.composer /var/www/wiki

# MediaWiki installation
USER www-data
WORKDIR /var/www/wiki

# Download & unpack MediaWiki release
RUN curl --fail --location --show-error --silent \
        "https://releases.wikimedia.org/mediawiki/${MW_VERSION%.*}/mediawiki-${MW_VERSION}.tar.gz" \
    | tar --extract --gzip --strip-components=1
