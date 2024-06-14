ARG PS_VERSION
ARG PHP_VERSION
ARG PHP_FLAVOUR
ARG SERVER_FLAVOUR
ARG GIT_SHA
ARG ZIP_SOURCE

# ==================================
# Stage 1/3: PHP base configuration
# ==================================
FROM php:${PHP_FLAVOUR} AS alpine-base-prestashop
ARG PS_VERSION
ARG SERVER_FLAVOUR

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

# Install base tools
RUN \
  apk --no-cache add -U \
  ca-certificates geoip tzdata zip curl jq make fcgi \
  gnu-libiconv php-common mariadb-client oniguruma-dev \
  zlib-dev libzip-dev libjpeg-turbo-dev libpng-dev \
  icu-dev libmcrypt-dev libxml2 libxml2-dev \
  && /tmp/php-configuration.sh \
  && apk del make \
  && rm -rf /var/cache/apk/*

RUN if [ "$SERVER_FLAVOUR" = "apache" ]; then \
    apk --no-cache add -U apache2 apache2-proxy apache2-tools; \
    printf '\
#!/bin/sh\n\
# Only for Alpine linux, not supporting this file by default\n\
php-fpm -D\n\
/usr/sbin/httpd -D FOREGROUND\n\
 ' > /usr/bin/apache-foreground; \
  chmod +x /usr/bin/apache-foreground; \
elif [ "$SERVER_FLAVOUR" = "nginx" ]; then \
    apk --no-cache add -U nginx nginx-mod-http-headers-more nginx-mod-http-geoip \
    nginx-mod-stream nginx-mod-stream-geoip; \
    printf '\
#!/bin/sh\n\
php-fpm -D\n\
nginx -g "daemon off;"\n\
 ' > /usr/bin/nginx-foreground; \
    chmod +x /usr/bin/nginx-foreground; \
fi

## Healthcheck
RUN if [ "$SERVER_FLAVOUR" = "apache" ]; then \
    printf '\
    #!/bin/sh\n\
    curl -Isf http://localhost:80/robots.txt || exit 1' > /tmp/healthcheck; \
  elif [ "$SERVER_FLAVOUR" = "nginx" ]; then \
    printf '\
    #!/bin/sh\n\
    curl -Isf http://localhost:80/robots.txt || exit 1' > /tmp/healthcheck; \
  else \
    printf '\
    #!/bin/sh\n\
    cgi-fcgi -bind -connect localhost:9000' > /tmp/healthcheck; \
  fi; \
  chmod +x /tmp/healthcheck;

# Add configuration
COPY ./assets/nginx.conf /tmp/
COPY ./assets/php-fpm*.conf /tmp/

# The PrestaShop docker entrypoint
COPY ./assets/docker_run.sh /tmp/

RUN if [ "$SERVER_FLAVOUR" = "fpm" ]; then \
      sed -i 's/{PHP_CMD}/php-fpm -R/' /tmp/docker_run.sh; \
      mv /tmp/php-fpm-standalone.conf /usr/local/etc/php-fpm.conf; \
    elif [ "$SERVER_FLAVOUR" = "nginx" ]; then \
      sed -i 's/{PHP_CMD}/nginx-foreground/' /tmp/docker_run.sh; \
      mv /tmp/php-fpm-local.conf /usr/local/etc/php-fpm.conf; \
      mv /tmp/nginx.conf /etc/nginx/nginx.conf; \
      mkdir -p /var/run/php; \
    else \
      sed -i 's/{PHP_CMD}/apache2-foreground/' /tmp/docker_run.sh; \
    fi; \
    rm -rf /tmp/*.conf;

# Handling a dynamic domain
# Probably, or at least its usage must be described in the README file
# COPY ./assets/docker_updt_ps_domains.php /tmp/

# PHP env for dev / demo modes
# COPY ./assets/defines_custom.inc.php /tmp/
# RUN chown www-data:www-data /tmp/defines_custom.inc.php

# Apache configuration
RUN if [ -x "$(command -v apache2-foreground)" ]; then \
  a2enmod rewrite;\
  fi

# =========================================
# Stage 2/3: PrestaShop sources downloader
# =========================================
FROM alpine-base-prestashop AS alpine-download-prestashop
ARG PS_VERSION
ARG GIT_SHA
ARG PHP_VERSION
ARG SERVER_FLAVOUR
ARG PS_FOLDER=/var/www/html
ARG ZIP_SOURCE

# Get PrestaShop source code
# hadolint ignore=DL3020
ADD ${ZIP_SOURCE} /tmp/prestashop.zip

# Extract the souces
RUN mkdir -p "$PS_FOLDER" /tmp/unzip-ps \
  && unzip -n -q /tmp/prestashop.zip -d /tmp/unzip-ps \
  && ([ -f /tmp/unzip-ps/prestashop.zip ] \
  && unzip -n -q /tmp/unzip-ps/prestashop.zip -d "$PS_FOLDER" \
  || mv /tmp/unzip-ps/prestashop/* "$PS_FOLDER") \
  && chown -R www-data:www-data "$PS_FOLDER" \
  && rm -rf /tmp/prestashop.zip /tmp/unzip-ps

# Ship a VERSION file
RUN echo "PrestaShop $PS_VERSION" > "$PS_FOLDER/VERSION" \
  && echo "PHP $PHP_VERSION" >> "$PS_FOLDER/VERSION" \
  && echo "Server $SERVER_FLAVOUR" >> "$PS_FOLDER/VERSION" \
  && echo "Git SHA $GIT_SHA" >> "$PS_FOLDER/VERSION" \

# Adds a robots.txt file
COPY ./assets/robots.txt $PS_FOLDER

# ============================
# Stage 3/3: Production image
# ============================
FROM alpine-base-prestashop
ARG PS_FOLDER=/var/www/html
ARG PS_VERSION

LABEL maintainer="PrestaShop Core Team <coreteam@prestashop.com>"

COPY --chown=www-data:www-data --from=alpine-download-prestashop ${PS_FOLDER} ${PS_FOLDER}

HEALTHCHECK --interval=5s --timeout=5s --retries=10 --start-period=10s \
  CMD /tmp/healthcheck

EXPOSE 80

STOPSIGNAL SIGQUIT

ENTRYPOINT ["/tmp/docker_run.sh"]
