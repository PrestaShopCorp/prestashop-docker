#!/bin/bash
# https://gist.github.com/mohanpedala/1e2ff5661761d3abd0385e8223e16425
set -euo pipefail

function error {
  echo -e "\e[1;31m${1:-Unknown error}\e[0m"
  exit "${2:-1}"
}

# Get latest version of PrestaShop (via GitHub)
function get_latest_prestashop_version {
  curl --silent --location --request GET 'https://api.github.com/repos/prestashop/prestashop/releases/latest' | jq -r '.tag_name'
}

# Get recommended PHP version from `prestashop-versions.json`
#
# $1 - PrestaShop version
#
# Examples:
# - get_recommended_php_version "8.0.4"
function get_recommended_php_version {
  PS_VERSION=$1
  RECOMMENDED_VERSION=
  REGEXP_LIST=$(jq -r 'keys_unsorted | .[]' <prestashop-versions.json)

  while IFS= read -r regExp; do
    if [[ $PS_VERSION =~ $regExp ]]; then
      RECOMMENDED_VERSION=$(jq -r '."'"${regExp}"'".php.recommended' <prestashop-versions.json)
      break
    fi
  done <<<"$REGEXP_LIST"
  echo "$RECOMMENDED_VERSION"
}

# Check if the image exists on the Docker hub
# https://docs.docker.com/docker-hub/api/latest
#
# $1 - Namespace (library for official images)
# $2 - Repository
# $3 - Tag
#
# Examples:
# - check_if_image_exists_on_hub "library" "php" "8.2-apache"
# - check_if_image_exists_on_hub "venatum" "bull-board" "1.0"
function check_if_image_exists_on_hub {
  namespace=$1
  repository=$2
  tag=$3
  curl --silent --location --head --fail "https://hub.docker.com/v2/namespaces/$namespace/repositories/$repository/tags/$tag" >/dev/null
  echo $?
}

# Main workflow
DOCKER_REPOSITORY="${DOCKER_REPOSITORY:-prestashop/prestashop}"
PS_VERSION="${PS_VERSION:-$(get_latest_prestashop_version)}"
RECOMMENDED_VERSION=$(get_recommended_php_version "$PS_VERSION")
PHP_VERSION="${PHP_VERSION:-$RECOMMENDED_VERSION}"
if [[ -z $PHP_VERSION ]]; then
  error "Could not find a recommended PHP version for ${PS_VERSION}" 2
fi
PHP_FLAVOUR="${PHP_FLAVOUR:-apache}"
PHP_DOCKER_TAG="${PHP_VERSION}-${PHP_FLAVOUR}"
LINUX_DISTRIBUTION="${LINUX_DISTRIBUTION:-debian}"

# Check PHP flavour ? (in the list)
# Check linux distribution ? (in the list)

# Check the existance of the php image
if [[ $(check_if_image_exists_on_hub library php "$PHP_DOCKER_TAG") -ne 0 ]]; then
  echo "We could not find this image tag: $PHP_DOCKER_TAG"
  error "Please check availability on https://hub.docker.com/_/php"
fi

echo "🐳 Use $DOCKER_REPOSITORY"
echo "Use PrestaShop $PS_VERSION with PHP $PHP_VERSION on $LINUX_DISTRIBUTION"

#TAGS=$(get_tag_aliases "$DOCKER_REPOSITORY" "$PS_VERSION" "$PHP_FLAVOUR")
if [[ "$PS_VERSION" == "nightly" ]]; then
  TAGS="--tag $DOCKER_REPOSITORY:nightly";
  echo "Ready to create: $DOCKER_REPOSITORY:nightly"
else
  TAGS="--tag $DOCKER_REPOSITORY:$PS_VERSION-$PHP_DOCKER_TAG --tag $DOCKER_REPOSITORY:latest";
  echo "Ready to create: $DOCKER_REPOSITORY:$PS_VERSION-$PHP_DOCKER_TAG"
fi


docker buildx build \
  ${BUILDPLATFORM:+"--platform=$BUILDPLATFORM"} \
  --build-arg PHP_DOCKER_TAG="${PHP_DOCKER_TAG}" \
  --build-arg PS_VERSION="${PS_VERSION}" \
  --cache-from type=registry,ref=$DOCKER_REPOSITORY:latest \
  --cache-to type=inline \
  --file ./docker/$LINUX_DISTRIBUTION-base.Dockerfile \
  $TAGS \
  ./docker

# --------------------------------
#  - Check if release exists before ?

## Specific version
#DOWNLOAD_URL=$(curl --location --request GET 'https://api.github.com/repos/prestashop/prestashop/releases'| jq -r '.[] | select(.tag_name | contains("$PS_VERSION")) | .assets[] | select(.name | contains(".zip")) | .browser_download_url')
## latest
#DOWNLOAD_URL=$(curl --location --request GET 'https://api.github.com/repos/prestashop/prestashop/releases/latest' | jq -r '.assets[] | select(.name | contains(".zip")) | .browser_download_url')
#curl -o ./prestashop.zip -L $DOWNLOAD_URL
## Nightly
#git clone 'https://github.com/PrestaShop/PrestaShop.git'

function check_if_image_exists {
  DOCKER_IMAGE=$1
  docker manifest inspect "$DOCKER_IMAGE" >/dev/null
  echo $?
}

function get_tag_aliases {
  DOCKER_REPOSITORY=$1
  PS_VERSION=$2
  PHP_FLAVOUR=$3

  REGEXP_TAGS=
  REGEXP_LIST=$(jq -r 'keys_unsorted | .[]' <prestashop-tags.json)

  while IFS= read -r regExp; do
    if [[ $PS_VERSION =~ $regExp ]]; then
      REGEXP_TAGS=$(jq -r '."'"${regExp}"'".'"${PHP_FLAVOUR}"' | .[]' <prestashop-tags.json)
      break
    fi
  done <<<"$REGEXP_LIST"
  echo "$REGEXP_TAGS"

  # --tag="${DOCKER_REPOSITORY}:${TAG}"\
  #  for tag in tags; do
  #    return "--tag ${DOCKER_REPOSITORY}/"
  #  done;
}
