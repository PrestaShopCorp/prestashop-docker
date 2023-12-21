ARG PS_VERSION
ARG PHP_VERSION
ARG PHP_FLAVOUR

# ==================================
# Stage 1/3: PHP base configuration
# ==================================
FROM php:${PHP_FLAVOUR} AS alpine-base-prestashop
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
RUN apk --no-cache add -U $GD_DEPS $ZIP_DEPS $INTL_DEPS \
  && docker-php-ext-configure gd --with-jpeg \
  && docker-php-ext-install gd pdo_mysql zip intl;
#   docker-php-ext-enable opcache

RUN docker-php-ext-configure gd --with-freetype=/usr/include/ --with-jpeg=/usr/include/ --with-webp=/usr/include
RUN docker-php-ext-install iconv intl pdo_mysql mbstring soap gd zip bcmath

RUN docker-php-source extract \
    && if [ -d "/usr/src/php/ext/mysql" ]; then docker-php-ext-install mysql; fi \
    && if [ -d "/usr/src/php/ext/mcrypt" ]; then docker-php-ext-install mcrypt; fi \
    && if [ -d "/usr/src/php/ext/opcache" ]; then docker-php-ext-install opcache; fi \
    && docker-php-source delete

# The PrestaShop docker entrypoint
COPY config_files/docker_run.sh /tmp/

# Handling a dynamic domain
COPY config_files/docker_updt_ps_domains.php /tmp/

# PHP env for dev / demo modes
COPY config_files/defines_custom.inc.php /tmp/
RUN chown www-data:www-data /tmp/defines_custom.inc.php

# Apache configuration
RUN if [ -x "$(command -v apache2-foreground)" ]; then a2enmod rewrite; fi

# PHP configuration
COPY config_files/php.ini /usr/local/etc/php/

# @TODO check opcache
# RUN echo '\
#   opcache.interned_strings_buffer=16\n\
#   opcache.load_comments=Off\n\
#   opcache.max_accelerated_files=16000\n\
#   opcache.save_comments=Off\n\
#   ' >> /usr/local/etc/php/conf.d/docker-php-ext-opcache.ini

# Disable IPv6
# RUN echo "net.ipv6.conf.all.disable_ipv6 = 1" | tee /etc/sysctl.conf

# =========================================
# Stage 2/3: PrestaShop sources downloader
# =========================================
FROM alpine-base-prestashop AS alpine-download-prestashop
ARG PS_VERSION

RUN apk --no-cache add -U git jq make

RUN if [[ "$PS_VERSION" == "nightly" ]]; then \
    git clone --depth 1 'https://github.com/PrestaShop/PrestaShop.git' /tmp/prestashop; \
    rm -rf /tmp/prestashop/.git; \
    make install; \
  else \
    DOWNLOAD_URL=$(curl -s -L --request GET 'https://api.github.com/repos/prestashop/prestashop/releases/latest' | jq -r '.assets[] | select(.name | contains(".zip")) | .browser_download_url'); \
    curl -s -L -o /tmp/prestashop.zip "${DOWNLOAD_URL}"; \
    unzip -n -q /tmp/prestashop.zip -d /tmp/prestashop; \
  fi

# ============================
# Stage 3/3: Production image
# ============================
FROM alpine-base-prestashop
ARG PS_FOLDER=/var/www/html

LABEL maintainer="PrestaShop Core Team <coreteam@prestashop.com>"

ENV PS_VERSION $PS_VERSION

# Copy the PrestaShop sources
COPY --chown=www-data:www-data --from=alpine-download-prestashop /tmp/prestashop ${PS_FOLDER}/prestashop

CMD ["/tmp/docker_run.sh"]
