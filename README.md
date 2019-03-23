*WARNING - This Docker image is designed for development use only*

This is a PHP 7.2 + Apache 2 image based on the official php image. It features
the following:

Apache modules
--------------

The following Apache modules are enabled:

* expires
* headers
* rewrite

PHP extensions
--------------

The following PHP extensions are installed and enabled:

* mysqli
* pdo_mysql
* mbstring
* gd
* curl
* opcache
* bcmath
* redis
* imagick
* jsmin
* xdebug
* apcu
* brotli

OS packages
-----------

The following software is installed:

* git
* vim
* powerline

Other
-----

Drush Launcher and Composer are installed as well. A user and group named
'application' are made available for optionally owning the files of the
application.
