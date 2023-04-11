#!/bin/bash
#set -e -x

function get_latest_prestashop_version {
  curl --silent --location --request GET 'https://api.github.com/repos/prestashop/prestashop/releases/latest' | jq -r '.tag_name'
}

# TODO: remove regex from prestashop-versions
function get_recommended_php_version {
  PS_VERSION=$1
  jq -r '.["$PS_VERSION"].php.recommended' < prestashop-versions.json
}

function check_if_image_exists {
  DOCKER_IMAGE=$1
  docker manifest inspect "$DOCKER_IMAGE" > /dev/null
  echo $?
}
# https://docs.docker.com/docker-hub/api/latest
function check_if_image_exists_on_hub {
  namespace=$1
  repository=$2
  tag=$3
  curl --silent --location --head --fail "https://hub.docker.com/v2/namespaces/$namespace/repositories/$repository/tags/$tag" > /dev/null
  echo $?
}

function get_tag_aliases {
  # --tag="${DOCKER_REPOSITORY}:${TAG}"\
  for tag in tags; do
    return "--tag ${DOCKER_REPOSITORY}/"
  done;
}

DOCKER_REPOSITORY="${DOCKER_REPOSITORY:-prestashop/prestashop}"
PS_VERSION="${PS_VERSION:-$(get_latest_prestashop_version)}"
PHP_VERSION="${PHP_VERSION:-$(get_recommended_php_version $PS_VERSION)}"
PHP_FLAVOUR="${PHP_FLAVOUR:-apache}"
PHP_DOCKER_TAG="${PHP_VERSION}-${PHP_FLAVOUR}"
LINUX_DISTRIBUTION="${LINUX_DISTRIBUTION:-debian}"

echo "$DOCKER_REPOSITORY"
echo "$PS_VERSION"
echo "$PHP_VERSION"
echo "$LINUX_DISTRIBUTION"
echo "$PHP_DOCKER_TAG"

#if [[ $(check_if_image_exists "php:$PHP_DOCKER_TAG") -ne 0 ]]; then
if [[ $(check_if_image_exists_on_hub library php "$PHP_DOCKER_TAG") -ne 0 ]]; then
  echo "Please check that this tag exists: $PHP_DOCKER_TAG"
  echo "https://hub.docker.com/"
fi

## TODO:
#  - penser au docker login avant -> docker login -u "$USER" -p "$PASSWORD" "$REGISTRY" ou Action Github
#  - [x] check here if php=$PHP_DOCKER_TAG exists
#  - Check if image already exists on Docker Hub before pushing ?
#  - Check if release exists before ?

## Specific version
#DOWNLOAD_URL=$(curl --location --request GET 'https://api.github.com/repos/prestashop/prestashop/releases'| jq -r '.[] | select(.tag_name | contains("$PS_VERSION")) | .assets[] | select(.name | contains(".zip")) | .browser_download_url')
## latest
#DOWNLOAD_URL=$(curl --location --request GET 'https://api.github.com/repos/prestashop/prestashop/releases/latest' | jq -r '.assets[] | select(.name | contains(".zip")) | .browser_download_url')
#curl -o ./prestashop.zip -L $DOWNLOAD_URL
## Nightly
#git clone 'https://github.com/PrestaShop/PrestaShop.git'

#TAGS=$(get_tag_aliases $PS_VERSION $PS)
#
## --platform linux/amd64,linux/arm64,linux/arm
#docker buildx build \
#  -f docker/${LINUX_DISTRIBUTION}-base.Dockerfile \
#  --build-arg PHP_DOCKER_TAG=${PHP_DOCKER_TAG} \
#  --build-arg PS_VERSION=${PS_VERSION} \
#  $TAGS \
#  .
