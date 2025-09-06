ARG DEBIAN_VERSION="13"
ARG PHP_VERSION="8.4"

FROM docker.io/krystalcode/d_debian:{DEBIAN_VERSION} as debian

FROM docker.io/krystalcode/d_ble_sh:{DEBIAN_VERSION}-latest as ble.sh

FROM docker.io/krystalcode/d_atuin:{DEBIAN_VERSION}-latest as atuin

FROM docker.io/krystalcode/d_just:{DEBIAN_VERSION}-latest as just

FROM docker.io/library/php:${PHP_VERSION}-apache

ENV PHP_EXTENSION_MAKE_DIR=/tmp/php-make

    # Install OS packages required.
    # Required by php extensions: libcurl4-gnutls-dev imagemagick
    #   libmagickwand-dev libjpeg-dev libpng-dev libfreetype6-dev libbrotli-dev
    # Required by composer for installing certain packages: git unzip
    # Required by Drupal/Drush for communicating with the database: default-mysql-client
    # Required for text editing: vim
    # Required for `ble.sh`: gawk
RUN apt-get update && \
    apt-get -y install \
    libcurl4-gnutls-dev \
    imagemagick \
    libmagickwand-dev \
    libjpeg-dev \
    libpng-dev \
    libfreetype6-dev \
    libonig-dev \
    libbrotli-dev \
    git \
    unzip \
    default-mysql-client \
    vim \
    gawk && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

    # We install PHP extensions on a separate RUN command because we change
    # directories for building some extensions from source. Changing directory
    # is carried over within the rest of the commands but it is reset to the
    # WORKDIR on the next RUN command. This way we avoid accidentally running
    # commands in the wrong directory - has happened. We will be squashing the
    # image layers anyway.
    # Create the directory used for building extensions from source.
RUN mkdir ${PHP_EXTENSION_MAKE_DIR} && \
    # Install php extensions required by Drupal.
    docker-php-ext-configure gd --with-freetype --with-jpeg && \
    docker-php-ext-install mysqli pdo_mysql mbstring gd curl opcache bcmath && \
    # Install the PhpRedis extension required by the 'redis' module, used for
    # improved cache performance.
    printf "\n" | pecl install redis && \
    docker-php-ext-enable redis && \
    # Install the Imagick extension used by the 'imagick' module as the image
    # toolkit.
    printf "\n" | pecl install imagick && \
    docker-php-ext-enable imagick && \
    # Install the `xdebug` extension used for development/debugging purposes.
    printf "\n" | pecl install xdebug-3.2.2 && \
    docker-php-ext-enable xdebug && \
    # Install the `apcu` extension used by `xautoload` as its cache mode.
    printf "\n" | pecl install apcu && \
    docker-php-ext-enable apcu && \
    # Install the JSMin extension used by the 'advagg' module for faster js
    # minification.
    # We use a fork until there is a PHP 8-compatible release.
    cd ${PHP_EXTENSION_MAKE_DIR} && \
    git clone --recursive --depth=1 -b php81 https://github.com/skilld-labs/pecl-jsmin.git && \
    cd ${PHP_EXTENSION_MAKE_DIR}/pecl-jsmin && \
    phpize && \
    ./configure && \
    make && \
    make install clean && \
    printf '%s\n' 'extension=jsmin.so'  >> /usr/local/etc/php/conf.d/jsmin.ini && \
    rm -rf ${PHP_EXTENSION_MAKE_DIR}/pecl-jsmin && \
    # Install the `brotli` extension used by the `advagg` module for CSS/JS
    # compression.
    cd ${PHP_EXTENSION_MAKE_DIR} && \
    git clone --recursive --depth=1 https://github.com/kjdev/php-ext-brotli.git && \
    cd ${PHP_EXTENSION_MAKE_DIR}/php-ext-brotli && \
    phpize && \
    ./configure --with-libbrotli && \
    make && \
    make install && \
    printf '%s\n' 'extension=brotli.so'  >> /usr/local/etc/php/conf.d/brotli.ini && \
    rm -rf ${PHP_EXTENSION_MAKE_DIR}/php-ext-brotli && \
    # Clean up.
    rm /tmp/pear -rf

    # Enable 'mod_expires' and 'mod_headers' apache modules required by the
    # 'advagg' module for properly setting headers.
    # Enable 'mod_rewrite' apache module for URL rewriting.
RUN a2enmod expires headers rewrite && \
    # Install 'composer'.
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/bin --filename=composer && \
    # Create a user that should own the application files.
    groupadd -r application && useradd -r -g application application

# Add command for running Composer from anywhere in the filesystem.
ADD ./commands/c /usr/local/bin/c

# Add command for running Drush from anywhere in the filesystem.
ADD ./commands/d /usr/local/bin/d

# Add command for resetting file permissions.
ADD ./commands/p /usr/local/bin/p

# Add command for running another command multiple times.
ADD ./commands/r /usr/local/bin/r

# Add apache configuration file.
# The only change compared to the default file is that it changes the document
# root to be the /var/www/html/web folder as required by Drupal.
#
# @I Include all .htaccess files when the server is starting
#    type     : improvement
#    priority : normal
#    labels   : performance
COPY apache2.conf /etc/apache2/sites-available/000-default.conf

# PHP configuration.
ADD php-application-errors.ini /usr/local/etc/php/conf.d/application-errors.ini
ADD php-application-execution.ini /usr/local/etc/php/conf.d/application-execution.ini
ADD php-application-uploads.ini /usr/local/etc/php/conf.d/application-uploads.ini
ADD php-application-xdebug.ini /usr/local/etc/php/conf.d/application-xdebug.ini

# Bash extensions.
COPY --from=debian /root/.bashrc /root/
COPY --from=debian /root/.bashrc.d /root/.bashrc.d
COPY .bashrc.d/composer.sh /root/.bashrc.d/

# `dotenv`.
COPY --from=debian /usr/bin/dotenv /usr/bin/dotenv

# `ble.sh`.
COPY --from=ble.sh /root/.local/share/blesh /root/.local/share/blesh
COPY --from=ble.sh /root/.local/share/doc/blesh /root/.local/share/doc/blesh

RUN sed -i '1s/^/[[ $- == *i* ]] \&\& source ~\/.local\/share\/blesh\/ble\.sh --noattach\n\n/' ~/.bashrc && \
    echo '[[ ! ${BLE_VERSION-} ]] || ble-attach' >> ~/.bashrc

# Oh My Posh.
# The Bash extension is copied in the "Bash extensions" section above.
COPY --from=debian /usr/bin/oh-my-posh /usr/bin/
COPY --from=debian /root/.config/oh-my-posh/themes/runnah.minimal.omp.json /root/.config/oh-my-posh/themes/runnah.minimal.omp.json

# Atuin.
COPY --from=atuin /usr/bin/atuin /usr/bin/
COPY --from=atuin /root/.bashrc.d/atuin-client.sh /root/.bashrc.d/

# Just.
COPY --from=just /usr/bin/just /usr/bin/
ADD ./commands/j /usr/local/bin/j
