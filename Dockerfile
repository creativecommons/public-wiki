# https://docs.docker.com/engine/reference/builder/
# https://hub.docker.com/_/debian
FROM debian:bookworm-slim

# Configure apt not to prompt during docker build
ARG DEBIAN_FRONTEND=noninteractive

# Configure apt to avoid installing recommended and suggested packages
RUN apt-config dump \
  | grep -E '^APT::Install-(Recommends|Suggests)' \
  | sed -e's/1/0/' \
  | tee /etc/apt/apt.conf.d/99no-recommends-no-suggests

# Resynchronize the package index files from their sources
RUN apt-get update

# Install packagess
RUN apt-get install -y \
    apache2 \
    apache2-utils \
    ca-certificates \
    curl \
    git \
    less \
    mariadb-client \
    unzip \
    vim \
    wget \
    # PHP 8.2 + extensions commonly required by MediaWiki
    libapache2-mod-php \
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
    # Thumbnails / media processing
    imagemagick \
    php-imagick \
    && update-ca-certificates

# Clean up packages: Saves space by removing unnecessary package files
# and lists
RUN apt-get clean 
RUN rm -rf /var/lib/apt/lists/*

# Add www-data to sudo (mirroring your reference) and allow startup service
RUN adduser www-data sudo
COPY config/www-data_startupservice /etc/sudoers.d/www-data_startupservice

# Startup script (enables env pass-through & graceful startup)
COPY config/startupservice.sh /startupservice.sh
RUN chmod +x /startupservice.sh
CMD ["sudo", "--preserve-env", "/startupservice.sh"]

# Expose Apache
EXPOSE 80

# Enable useful Apache modules
RUN a2enmod headers && a2enmod rewrite && a2enmod php8.2

# Optional: PHP overrides (upload size, memory, etc.)
# Provide your own config/90-local.ini if desired
COPY config/90-local.ini /etc/php/8.2/apache2/conf.d/90-local.ini

# Install Composer (for extensions/skins that require it)
RUN curl -sS https://getcomposer.org/installer \
    | php -- --install-dir=/usr/local/bin --filename=composer

# Prepare web root
# We'll serve MediaWiki from /var/www/wiki (keeps it separate from /var/www/html default)
RUN mkdir -p /var/www/wiki \
    && chown -R www-data:www-data /var/www/wiki

# Download & unpack MediaWiki
# Example usage: docker build --build-arg MW_VERSION=1.41.2 -t my/mediawiki:1.41 .
USER www-data
WORKDIR /var/www/wiki
ARG MW_VERSION
ENV MW_VERSION=${MW_VERSION:-1.41.2}

# Fetch the specified version tarball from releases
# (Change mirror if needed; this uses releases.wikimedia.org)
RUN curl -fsSL "https://releases.wikimedia.org/mediawiki/${MW_VERSION%.*}/mediawiki-$MW_VERSION.tar.gz" -o mediawiki.tar.gz \
    && tar -xzf mediawiki.tar.gz --strip-components=1 \
    && rm mediawiki.tar.gz

# Create directories MediaWiki expects to be writable
RUN mkdir -p images \
    && chmod 775 images

# Optional: pre-create a placeholder LocalSettings.php if you want non-interactive boot.
# By default, we let the web installer generate it on first run.
# COPY config/LocalSettings.php /var/www/wiki/LocalSettings.php

# Switch back to root for final touches
USER root

# Apache DocumentRoot -> point to /var/www/wiki
# Update the default site to serve MediaWiki directory
RUN sed -ri 's#DocumentRoot /var/www/html#DocumentRoot /var/www/wiki#' /etc/apache2/sites-available/000-default.conf \
    && sed -ri 's#<Directory /var/www/>#<Directory /var/www/wiki/>#' /etc/apache2/apache2.conf \
    && sed -ri 's#Options Indexes FollowSymLinks#Options FollowSymLinks#' /etc/apache2/apache2.conf

# Ensure permissions
RUN chown -R www-data:www-data /var/www/wiki

# Healthcheck (simple)
HEALTHCHECK --interval=30s --timeout=5s --retries=5 \
  CMD curl -fsS http://localhost/ || exit 1

