#!/bin/sh
set -eu

error() {
  printf "\e[1;31m%s\e[0m" "${1:-Unknown error}"
  exit "${2:-1}"
}

[ -z "$PHP_ENV" ] && error "PHP_ENV is not set" 2
[ -z "$PHP_VERSION" ] && error "PHP_VERSION is not set" 3

PS_PHP_EXT="bcmath fileinfo gd intl mbstring pdo_mysql simplexml soap zip";
PHP_GD_CONFIG="--with-jpeg";
#gd --with-freetype=/usr/include/ --with-jpeg=/usr/include/ --with-webp=/usr/include

if [ "7.1" = "$PHP_VERSION" ]; then
  PS_PHP_EXT="$PS_PHP_EXT mcrypt";
  PHP_GD_CONFIG="--with-gd --with-jpeg --with-jpeg-dir --with-zlib-dir";
elif [ "7.2" = "$PHP_VERSION" ] || [ "7.3" = "$PHP_VERSION" ]; then
  PHP_GD_CONFIG="--with-jpeg-dir --with-zlib-dir";
fi

# shellcheck disable=SC2086
docker-php-ext-configure gd $PHP_GD_CONFIG
# shellcheck disable=SC2086
docker-php-ext-install $PS_PHP_EXT;

if [ "production" = "$PHP_ENV" ]; then
  mv "${PHP_INI_DIR}/php.ini-production" "${PHP_INI_DIR}/php.ini"
  rm -f "${PHP_INI_DIR}/php.ini-development";
else
  mv "${PHP_INI_DIR}/php.ini-development" "${PHP_INI_DIR}/php.ini"
  rm -f "${PHP_INI_DIR}/php.ini-production";
  sed -i 's/memory_limit = .*/memory_limit = -1/' "${PHP_INI_DIR}/php.ini"
fi

# Remove php assets that might have been installed by package unaware of $PHP_INI_DIR
rm -rf /etc/php* /usr/lib/php*