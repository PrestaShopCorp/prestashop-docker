#!/bin/bash
set -e -x

function get_latest_prestashop_version {
  return "$(curl --location --request GET 'https://api.github.com/repos/prestashop/prestashop/releases/latest' | jq -r '.tag_name')"
}

# TODO: remove regex from prestashop-versions
function get_recommended_php_version {
  PS_VERSION=$0
  return "$(jq -r '.["$PS_VERSION"].php.recommended' < prestashop-versions.json)"
}

function get_tag_aliases {
  # --tag="${DOCKER_REPOSITORY}:${TAG}"\
  for tag in tags; do
    return "--tag ${DOCKER_REPOSITORY}/"
  done;
}

DOCKER_REPOSITORY="${DOCKER_REPOSITORY:-prestashop/prestashop}"
PS_VERSION="${PS_VERSION:-get_latest_prestashop_version}"
PHP_VERSION="${PHP_VERSION}:-$(get_recommended_php_version)"
LINUX_DISTRIBUTION="${LINUX_DISTRIBUTION}-debian"
PHP_DOCKER_TAG="${PHP_VERSION}-${PHP_FLAVOUR}"
# check here if php=$PHP_DOCKER_TAG exists

# TODO:
#  - Check if image already exists on Docker Hub before pushing ?
#  - Check if release exists before ?

## Specific version
#DOWNLOAD_URL=$(curl --location --request GET 'https://api.github.com/repos/prestashop/prestashop/releases'| jq -r '.[] | select(.tag_name | contains("$PS_VERSION")) | .assets[] | select(.name | contains(".zip")) | .browser_download_url')
## latest
#DOWNLOAD_URL=$(curl --location --request GET 'https://api.github.com/repos/prestashop/prestashop/releases/latest' | jq -r '.assets[] | select(.name | contains(".zip")) | .browser_download_url')
#curl -o ./prestashop.zip -L $DOWNLOAD_URL
## Nightly
#git clone 'https://github.com/PrestaShop/PrestaShop.git'

TAGS=$(get_tag_aliases $PS_VERSION $PS)

# --platform linux/amd64,linux/arm64,linux/arm
docker buildx build \
  -f docker/${LINUX_DISTRIBUTION}-base.Dockerfile \
  --build-arg PHP_DOCKER_TAG=${PHP_DOCKER_TAG} \
  --build-arg PS_VERSION=${PS_VERSION} \
  $TAGS \
  .
