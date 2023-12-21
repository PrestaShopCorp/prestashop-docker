ARG PS_VERSION
ARG PHP_VERSION
ARG PHP_FLAVOUR

# ==================================
# Stage 1/3: PHP base configuration
# ==================================
FROM php:${PHP_FLAVOUR} AS debian-base-prestashop
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
PS_FOLDER_INSTALL=install \
PHP_ENV=production

# The PHP configuration script
COPY ./assets/php-configuration.sh /tmp/

RUN export DEBIAN_FRONTEND=noninteractive \
    && apt-get update \
    && apt-get install --no-install-recommends -qqy \
      default-mysql-client \
      jq \
      libfreetype6-dev \
      libicu-dev \
      libjpeg62-turbo-dev \
      libmcrypt-dev \
      libonig-dev \
      libpcre3-dev \
      libpng-dev \
      libwebp-dev \
      libxml2-dev \
      libzip-dev \
      unzip \
      wget \
    && /tmp/php-configuration.sh \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# The PrestaShop docker entrypoint
COPY ./assets/docker_run.sh /tmp/

# Handling a dynamic domain
# Probably, or at least its usage must be described in the README file
# COPY ./assets/docker_updt_ps_domains.php /tmp/

# PHP env for dev / demo modes
# COPY ./assets/defines_custom.inc.php /tmp/
# RUN chown www-data:www-data /tmp/defines_custom.inc.php

# Apache configuration
RUN if [ -x "$(command -v apache2-foreground)" ]; then\
    a2enmod rewrite;\
    fi

# =========================================
# Stage 2/3: PrestaShop sources downloader
# =========================================
FROM debian-base-prestashop AS debian-download-prestashop
ARG PS_VERSION
ENV PS_FOLDER=/tmp/prestashop

# Get PrestaShop source code
RUN if [[ "$PS_VERSION" == "nightly" ]]; then \
    echo "Unsupported yet: https://prestashop.slack.com/archives/C03LFE4KV6K/p1703170152828039" \
    && exit 1; \
  else \
    curl -s -L -o /tmp/prestashop.zip "https://github.com/PrestaShop/PrestaShop/releases/download/${PS_VERSION}/prestashop_${PS_VERSION}.zip"; \
  fi

# Extract the souces
RUN mkdir -p "$PS_FOLDER" /tmp/unzip-ps \
  && unzip -n -q /tmp/prestashop.zip -d /tmp/unzip-ps \
  && ([ -f /tmp/unzip-ps/prestashop.zip ] \
    && unzip -n -q /tmp/unzip-ps/prestashop.zip -d "$PS_FOLDER" \
    || mv /tmp/unzip-ps/prestashop/* "$PS_FOLDER")

# ============================
# Stage 3/3: Production image
# ============================
FROM debian-base-prestashop
ARG PS_FOLDER=/var/www/html/prestashop

LABEL maintainer="PrestaShop Core Team <coreteam@prestashop.com>"

ENV PS_VERSION $PS_VERSION

# Copy the PrestaShop sources
COPY --chown=www-data:www-data --from=debian-download-prestashop /tmp/prestashop ${PS_FOLDER}

CMD ["/tmp/docker_run.sh"]
