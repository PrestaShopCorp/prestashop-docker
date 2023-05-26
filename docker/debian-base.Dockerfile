ARG PS_VERSION
ARG PHP_DOCKER_TAG

# ==================================
# Stage 1/3: PHP base configuration
# ==================================
FROM php:${PHP_DOCKER_TAG} AS debian-base-prestashop
ARG PS_VERSION

ENV PS_DOMAIN="<to be defined>" \
DB_SERVER="<to be defined>" \
DB_PORT=3306 \
DB_NAME=prestashop \
DB_USER=root \
DB_PASSWD=admin \
DB_PREFIX=ps_ \
ADMIN_MAIL=demo@prestashop.com \
ADMIN_PASSWD=prestashop_demo \
PS_LANGUAGE=en \
PS_COUNTRY=GB \
PS_ALL_LANGUAGES=0 \
PS_INSTALL_AUTO=0 \
PS_ERASE_DB=0 \
PS_INSTALL_DB=0 \
PS_DEV_MODE=0 \
PS_HOST_MODE=0 \
PS_DEMO_MODE=0 \
PS_ENABLE_SSL=0 \
PS_HANDLE_DYNAMIC_DOMAIN=0 \
PS_FOLDER_ADMIN=admin \
PS_FOLDER_INSTALL=install

RUN DEBIAN_FRONTEND=noninteractive \
    apt-get update \
    && apt-get install -y libmcrypt-dev \
        libjpeg62-turbo-dev \
        libpcre3-dev \
        libpng-dev \
        libwebp-dev \
        libfreetype6-dev \
        libxml2-dev \
        libicu-dev \
        libzip-dev \
        default-mysql-client \
        wget \
        unzip \
        libonig-dev \
    && rm -rf /var/lib/apt/lists/*

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

# =========================================
# Stage 2/3: PrestaShop sources downloader
# =========================================
FROM debian-base-prestashop AS debian-download-prestashop
ARG PS_VERSION

RUN DEBIAN_FRONTEND=noninteractive \
    apt-get update \
    && apt-get install -y git jq make

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
FROM debian-base-prestashop
ARG PS_FOLDER=/var/www/html

LABEL maintainer="PrestaShop Core Team <coreteam@prestashop.com>"

ENV PS_VERSION $PS_VERSION

# Copy the PrestaShop sources
COPY --chown=www-data:www-data --from=debian-download-prestashop /tmp/prestashop ${PS_FOLDER}/prestashop

CMD ["/tmp/docker_run.sh"]
