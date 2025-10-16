# https://docs.docker.com/engine/reference/builder/

# https://hub.docker.com/_/debian
FROM debian:bookworm-slim

# Configure apt not to prompt during docker build
ARG DEBIAN_FRONTEND=noninteractive

# Configure apt to avoid installing recommended and suggested packages
RUN apt-config dump \
  | grep -E '^APT::Install-(Recommends|Suggests)' \
  | sed -e 's/1/0/' \
  | tee /etc/apt/apt.conf.d/99no-recommends-no-suggests

# Resynchronize the package index files from their sources
RUN apt-get update 

# Install packages
RUN apt-get install -y \
    apache2 \
    apache2-utils \
    ca-certificates \
    curl \
    git \
    less \
    mariadb-client \
    sudo \
    unzip \
    vim \
    wget \
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
    imagemagick \
    php-imagick \
    && update-ca-certificates \

# Clean up packages: Saves space by removing unnecessary package files
# and lists
RUN apt-get clean 

RUN rm -rf /var/lib/apt/lists/*

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
RUN a2enmod headers
RUN a2enmod php8.2
RUN a2enmod rewrite

# configure PHP 
COPY config/90-local.ini /etc/php/8.2/apache2/conf.d/

# Install Composer 
# https://getcomposer.org/doc/00-intro.md#installation-linux-unix-macos
RUN curl --silent --show-error https://getcomposer.org/installer \
    | php -- --install-dir=/usr/local/bin --filename=composer

# Create compose directory for www-data
RUN mkdir /var/www/.composer
RUN chown -R www-data:www-data /var/www/.composer

# Prepare MediaWiki directory
RUN mkdir -p /var/www/wiki/images 
RUN chown -R www-data:www-data /var/www/wiki

# MediaWiki installation
USER www-data
WORKDIR /var/www/wiki
ARG MW_VERSION
RUN [ -z "${MW_VERSION}" ] \
    || echo 'Environment variable MW_VERSION must be specified. Exiting.' \
    && exit 1
# Download & unpack MediaWiki release
RUN curl --fail --silent --show-error --location "https://releases.wikimedia.org/mediawiki/${MW_VERSION%.*}/mediawiki-$MW_VERSION.tar.gz" -o mediawiki.tar.gz \
    && tar -xzf mediawiki.tar.gz --strip-components=1 \
    && rm mediawiki.tar.gz

# Create writable directories
RUN mkdir -p images && chmod 775 images

