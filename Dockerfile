# https://docs.docker.com/engine/reference/builder/
# https://hub.docker.com/_/debian
FROM debian:bookworm-slim

# Prevent interactive apt prompts
ARG DEBIAN_FRONTEND=noninteractive

# Configure apt to skip recommended/suggested packages
RUN apt-config dump \
  | grep -E '^APT::Install-(Recommends|Suggests)' \
  | sed -e 's/1/0/' \
  | tee /etc/apt/apt.conf.d/99no-recommends-no-suggests

# Update and install dependencies
RUN apt-get update && apt-get install -y \
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
    # PHP 8.2 + common MediaWiki extensions
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
    && update-ca-certificates \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Enable Apache modules for MediaWiki
RUN a2enmod headers rewrite php8.2

# Configure Apache to serve from /var/www/wiki
RUN sed -ri 's#DocumentRoot /var/www/html#DocumentRoot /var/www/wiki#' /etc/apache2/sites-available/000-default.conf \
    && sed -ri 's#<Directory /var/www/>#<Directory /var/www/wiki/>#' /etc/apache2/apache2.conf \
    && sed -ri 's#Options Indexes FollowSymLinks#Options FollowSymLinks#' /etc/apache2/apache2.conf

# Optional: PHP overrides (upload size, memory, etc.)
COPY config/90-local.ini /etc/php/8.2/apache2/conf.d/90-local.ini

# Install Composer (for extensions/skins that require it)
RUN curl -sS https://getcomposer.org/installer \
    | php -- --install-dir=/usr/local/bin --filename=composer

# Startup script (keeps container running & starts Apache)
COPY config/startupservice.sh /startupservice.sh
RUN chmod +x /startupservice.sh
CMD ["/startupservice.sh"]

# Expose Apache HTTP port
EXPOSE 80

# Prepare MediaWiki directory
RUN mkdir -p /var/www/wiki/images && chown -R www-data:www-data /var/www/wiki

# Switch to www-data for MediaWiki installation
USER www-data
WORKDIR /var/www/wiki

# MediaWiki version argument
ARG MW_VERSION
ENV MW_VERSION=${MW_VERSION:-1.41.2}

# Download & unpack MediaWiki release
RUN curl -fsSL "https://releases.wikimedia.org/mediawiki/${MW_VERSION%.*}/mediawiki-$MW_VERSION.tar.gz" -o mediawiki.tar.gz \
    && tar -xzf mediawiki.tar.gz --strip-components=1 \
    && rm mediawiki.tar.gz

# Create writable directories
RUN mkdir -p images && chmod 775 images



