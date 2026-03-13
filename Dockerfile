# https://docs.docker.com/engine/reference/builder/

# https://hub.docker.com/_/debian
FROM debian:bookworm-slim

# Configure apt not to prompt during docker build
# Accept MediaWiki version from docker-compose.yml
ARG DEBIAN_FRONTEND=noninteractive MW_VERSION

# Configure apt to avoid installing recommended and suggested packages
RUN apt-config dump \
  | grep -E '^APT::Install-(Recommends|Suggests)' \
  | sed -e 's/1/0/' \
  | tee /etc/apt/apt.conf.d/99no-recommends-no-suggests

# Resynchronize the package index, install packages, and clean-up
# https://docs.docker.com/build/building/best-practices/#apt-get
RUN apt-get update \
    &&  apt-get install -y \
        apache2 \
        apache2-utils \
        ca-certificates \
        curl \
        imagemagick \
        less \
        libapache2-mod-php \
        mariadb-client \
        php-imagick \
        php8.2 \
        php8.2-cli \
        php8.2-common \
        php8.2-curl \
        php8.2-gd \
        php8.2-intl \
        php8.2-mbstring \
        php8.2-mysql \
        php8.2-xml \
        php8.2-zip \
        sudo \
        unzip \
        vim \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
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

# Enable Apache modules
RUN a2enmod headers \
  && a2enmod php8.2 \
  && a2enmod rewrite

# configure PHP
COPY config/90-local.ini /etc/php/8.2/apache2/conf.d/

# Install Composer
# https://getcomposer.org/doc/00-intro.md#installation-linux-unix-macos
RUN curl --fail --location --show-error --silent \
        'https://getcomposer.org/installer' \
    | php -- --install-dir=/usr/local/bin --filename=composer

# Create directories and assign permissions
RUN mkdir -p /var/www/.composer /var/www/wiki/images \
    && chown -R www-data:www-data /var/www/.composer /var/www/wiki

# MediaWiki installation
USER www-data
WORKDIR /var/www/wiki

# Download & unpack MediaWiki release
RUN curl --fail --location --show-error --silent \
        "https://releases.wikimedia.org/mediawiki/${MW_VERSION%.*}/mediawiki-${MW_VERSION}.tar.gz" \
    | tar --extract --gzip --strip-components=1
