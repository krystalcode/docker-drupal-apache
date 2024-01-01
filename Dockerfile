FROM docker.io/library/php:8.0-apache

ENV PHP_EXTENSION_MAKE_DIR=/tmp/php-make

    # Install OS packages required.
    # Required by php extensions: libcurl4-gnutls-dev imagemagick
    #   libmagickwand-dev libjpeg-dev libpng-dev libfreetype6-dev libbrotli-dev
    # Required by composer for installing certain packages: git unzip
    # Required by Drupal/Drush for communicating with the database: default-mysql-client
    # Required for text editing: vim
    # Required for better shell experience: powerline fonts-powerline
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
    powerline \
    fonts-powerline && \
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
    printf "\n" | pecl install xdebug && \
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
    groupadd -r application && useradd -r -g application application && \
    # Export the TERM environment variable.
    # Add Composer `bin` folder to the path.
    # Configure bash shell to use "powerline" by default.
    printf '\n%s\n%s\n%s\n%s\n\n\n%s\n%s\n%s\n%s\n%s\n\n' '# Export TERM environment variable' 'export TERM=xterm' '# Add Composer `bin` folder to the path' 'export PATH="/var/www/html/bin:$PATH"' '# Use powerline' 'powerline-daemon -q' 'POWERLINE_BASH_CONTINUATION=1' 'POWERLINE_BASH_SELECT=1' '. /usr/share/powerline/bindings/bash/powerline.sh'  >> ~/.bashrc && \
    # Include bash aliases file.
    printf '\n%s\n%s\n%s\n%s\n\n' '# Include bash aliases file.' 'if [ -f ~/.bash_aliases ]; then' '    . ~/.bash_aliases' 'fi'  >> ~/.bashrc

# Add command for running Composer from anywhere in the filesystem.
ADD ./commands/c /usr/local/bin/c

# Add command for running Drush from anywhere in the filesystem.
ADD ./commands/d /usr/local/bin/d

# Add apache configuration file.
# The only change compared to the default file is that it changes the document
# root to be the /var/www/html/web folder as required by Drupal.
#
# @I Include all .htaccess files when the server is starting
#    type     : improvement
#    priority : normal
#    labels   : performance
COPY apache2.conf /etc/apache2/sites-available/000-default.conf
