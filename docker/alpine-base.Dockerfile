ARG PS_VERSION
ARG PHP_VERSION

FROM php:${PHP_VERSION}-fpm-alpine AS alpine-base-prestashop
ARG PS_VERSION
ARG PS_FOLDER=/var/www/html

# Install base tools
RUN \
  apk --no-cache add -U \
  bash less vim geoip git tzdata zip curl \
  nginx nginx-mod-http-headers-more nginx-mod-http-geoip \
  nginx-mod-stream nginx-mod-stream-geoip ca-certificates \
  libmcrypt gnu-libiconv-libs php81-common && \
  rm -rf /var/cache/apk/*

# Install PHP requirements
# see: https://olvlvl.com/2019-06-install-php-ext-source
ENV GD_DEPS="zlib-dev libjpeg-turbo-dev libpng-dev"
ENV ZIP_DEPS="libzip-dev"
ENV INTL_DEPS="icu-dev"
RUN apk add -U $GD_DEPS $ZIP_DEPS $INTL_DEPS \
  && docker-php-ext-configure gd --with-jpeg \
  && docker-php-ext-install gd pdo_mysql zip intl;
#   docker-php-ext-enable opcache

# Get PrestaShop source code
ADD https://github.com/PrestaShop/PrestaShop/releases/download/${PS_VERSION}/prestashop_${PS_VERSION}.zip /tmp/prestashop.zip

# Extract the souces
ADD ./tools/ps-zip-extractor.sh /ps-zip-extractor.sh
RUN mkdir -p ${PS_FOLDER} \
  && unzip -q /tmp/prestashop.zip -d ${PS_FOLDER}/ \
  && bash /ps-zip-extractor.sh ${PS_FOLDER} www-data \
  && rm -rf /tmp/prestashop.zip /ps-zip-extractor.sh

# -----------------------
# Flashlight final image
# -----------------------
FROM base-prestashop as optimize-prestashop
ARG PS_VERSION
ARG PHP_VERSION
ARG PS_FOLDER=/var/www/html
WORKDIR ${PS_FOLDER}

# @TODO check opcache
# RUN echo '\
#   opcache.interned_strings_buffer=16\n\
#   opcache.load_comments=Off\n\
#   opcache.max_accelerated_files=16000\n\
#   opcache.save_comments=Off\n\
#   ' >> /usr/local/etc/php/conf.d/docker-php-ext-opcache.ini

# Disable IPv6
RUN echo "net.ipv6.conf.all.disable_ipv6 = 1" | tee /etc/sysctl.conf

# Setup default env
ENV MYSQL_HOST=mysql
ENV MYSQL_USER=prestashop
ENV MYSQL_PASSWORD=prestashop
ENV MYSQL_ROOT_PASSWORD=prestashop
ENV MYSQL_PORT=3306
ENV MYSQL_DATABASE=prestashop

# Ship the dump within the image
ADD ./dump-${PS_VERSION}-${PHP_VERSION}.sql /dump.sql

# The new default runner
ADD ./tools/sql-restore-and-run-nginx.sh /run.sh

ENTRYPOINT ["/run.sh"]