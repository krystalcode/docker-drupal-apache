FROM php:7.3-apache

ENV DRUSH_LAUNCHER_VERSION=0.6.0

    # Install OS packages required.
    # Required by php extensions: libcurl4-gnutls-dev imagemagick
    #   libmagickwand-dev libjpeg-dev libpng-dev libfreetype6-dev
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
    git \
    unzip \
    default-mysql-client \
    vim \
    powerline \
    fonts-powerline && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    # Install php extensions required by Drupal.
    docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ && \
    docker-php-ext-install mysqli pdo_mysql mbstring gd curl opcache bcmath && \
    # Install the PhpRedis extension required by the 'redis' module, used for
    # improved cache performance.
    printf "\n" | pecl install redis && \
    docker-php-ext-enable redis && \
    # Install the Imagick extension used by the 'imagick' module as the image
    # toolkit.
    printf "\n" | pecl install imagick && \
    docker-php-ext-enable imagick && \
    # Install the JSMin extension used by the 'advagg' module for faster js
    # minification.
    printf "\n" | pecl install jsmin && \
    docker-php-ext-enable jsmin && \
    # Install the `xdebug` extension used for development/debugging purposes.
    printf "\n" | pecl install xdebug && \
    docker-php-ext-enable xdebug && \
    # Install the `apcu` extension used by `xautoload` as its cache mode.
    printf "\n" | pecl install apcu && \
    docker-php-ext-enable apcu && \
    # Install the `brotli` extension used by the `advagg` module for CSS/JS
    # compression.
    git clone --recursive --depth=1 https://github.com/kjdev/php-ext-brotli.git && \
    cd php-ext-brotli && \
    phpize && \
    ./configure && \
    make && \
    make install && \
    printf '%s\n' 'extension=brotli.so'  >> /usr/local/etc/php/conf.d/brotli.ini && \
    rm -rf php-ext-brotli && \
    # Clean up.
    rm /tmp/pear -rf && \
    # Enable 'mod_expires' and 'mod_headers' apache modules required by the
    # 'advagg' module for properly setting headers.
    # Enable 'mod_rewrite' apache module for URL rewriting.
    a2enmod expires headers rewrite && \
    # Install 'drush-launcher'.
    curl -L -o \
      /usr/local/bin/drush \
      https://github.com/drush-ops/drush-launcher/releases/download/{$DRUSH_LAUNCHER_VERSION}/drush.phar && \
    chmod +x /usr/local/bin/drush && \
    # Install 'composer'.
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/bin --filename=composer && \
    # Create a user that should own the application files.
    groupadd -r application && useradd -r -g application application && \
    # Export the TERM environment variable.
    # Configure bash shell to use "powerline" by default.
    printf '\n%s\n%s\n\n\n%s\n%s\n%s\n%s\n%s\n\n' '# Export TERM environment variable' 'export TERM=xterm' '# Use powerline' 'powerline-daemon -q' 'POWERLINE_BASH_CONTINUATION=1' 'POWERLINE_BASH_SELECT=1' '. /usr/share/powerline/bindings/bash/powerline.sh'  >> ~/.bashrc && \
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
