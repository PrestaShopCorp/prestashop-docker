#!/bin/bash
set -e

# Available variables
# -------------------
declare PLATFORM;        # -- a comma separated list of target platforms (defaults to "linux/amd64")
declare OS_FLAVOUR;      # -- either "debian" (default) or "alpine"
declare PHP_VERSION;     # -- PHP version, defaults to recommended version for PrestaShop
declare PHP_FLAVOUR;     # -- PHP flavour, defaults apache
declare PS_VERSION;      # -- PrestaShop version, defaults to latest
declare TARGET_IMAGE;    # -- docker image name, defaults to "prestashop/prestashop-flashlight"
declare PUSH;            # -- set it to "true" if you want to push the resulting image

# Static configuration
# --------------------
DEFAULT_OS="debian";
DEFAULT_SERVER="apache";
DEFAULT_DOCKER_IMAGE=prestashop/prestashop
DEFAULT_PLATFORM=linux/amd64
GIT_SHA=$(git rev-parse HEAD)

error() {
  echo -e "\e[1;31m${1:-Unknown error}\e[0m"
  exit "${2:-1}"
}

# Get latest version of PrestaShop (via GitHub)
get_latest_prestashop_version() {
  curl --silent --location --request GET \
   'https://api.github.com/repos/prestashop/prestashop/releases/latest' | jq -r '.tag_name'
}

# Get recommended PHP version from `prestashop-versions.json`
#
# $1 - PrestaShop version
#
# Examples:
# - get_recommended_php_version "8.0.4"
get_recommended_php_version() {
  local PS_VERSION=$1;
  local RECOMMENDED_VERSION=;
  REGEXP_LIST=$(jq -r 'keys_unsorted | .[]' <prestashop-versions.json)
  while IFS= read -r regExp; do
    if [[ $PS_VERSION =~ $regExp ]]; then
      RECOMMENDED_VERSION=$(jq -r '."'"${regExp}"'".php.recommended' <prestashop-versions.json)
      break;
    fi
  done <<<"$REGEXP_LIST"
  echo "$RECOMMENDED_VERSION";
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
check_if_image_exists_on_hub() {
  namespace=$1
  repository=$2
  tag=$3
  curl --silent --location --head --fail "https://hub.docker.com/v2/namespaces/$namespace/repositories/$repository/tags/$tag" >/dev/null
  echo $?
}

get_php_flavour() {
   local OS_FLAVOUR=${1:-};
   local SERVER_FLAVOUR=${2:-};
   local PHP_VERSION=${3:-};
   jq -r '."'"${PHP_VERSION}"'".'"${OS_FLAVOUR}" <php-flavours.json;
}

get_ps_version() {
  local PS_VERSION=${1:-};
  if [ -z "$PS_VERSION" ] || [ "$PS_VERSION" == "latest" ] ; then
    get_latest_prestashop_version;
  else
    echo "$PS_VERSION";
  fi
}

get_php_version() {
  local PHP_VERSION=${1:-};
  local PS_VERSION=${2:-};
  if [ -z "$PHP_VERSION" ] || [ "$PHP_VERSION" == "latest" ] ; then
    get_recommended_php_version "$PS_VERSION"
  else
    echo "$PHP_VERSION";
  fi
}

#
# if the build is for the latest image of the default OS with the recommended PHP version, these tags will be like:
# * latest
# * 8.1.1
# * 8.1.1-8.2
# * 8.1.1-8.2-alpine
#
get_target_images() {
  local PHP_FLAVOUR=${1:-};
  local PS_VERSION=${2:-};
  local PHP_VERSION=${3:-};
  local OS_FLAVOUR=${4:-};
  declare RES;
  if [ "$PS_VERSION" = "$(get_latest_prestashop_version)" ] && [ "$OS_FLAVOUR" = "$DEFAULT_OS" ]; then
    RES="-t ${DEFAULT_DOCKER_IMAGE}:latest";
  fi
  if [ "$OS_FLAVOUR" = "$DEFAULT_OS" ]; then
    RES="${RES} -t ${DEFAULT_DOCKER_IMAGE}:${PS_VERSION}-${PHP_VERSION}";
    if [ "$PHP_VERSION" = "$(get_recommended_php_version "$PS_VERSION")" ]; then
      RES="${RES} -t ${DEFAULT_DOCKER_IMAGE}:${PS_VERSION}";
    fi
  fi
  RES="${RES} -t ${DEFAULT_DOCKER_IMAGE}:${PS_VERSION}-${PHP_FLAVOUR}";
  RES="${RES} -t ${DEFAULT_DOCKER_IMAGE}:${PS_VERSION}-${OS_FLAVOUR}";
  echo "$RES";
}

# Applying configuration
# ----------------------
PS_VERSION=$(get_ps_version "$PS_VERSION");
PHP_VERSION=$(get_php_version "$PHP_VERSION" "$PS_VERSION");
if [ -z "$PHP_VERSION" ]; then
  error "Could not find a recommended PHP version for PS_VERSION: $PS_VERSION" 2
fi
OS_FLAVOUR=${OS_FLAVOUR:-$DEFAULT_OS};
SERVER_FLAVOUR=${SERVER_FLAVOUR:-$DEFAULT_SERVER};
PHP_FLAVOUR=$(get_php_flavour "$OS_FLAVOUR" "$SERVER_FLAVOUR" "$PHP_VERSION");
if [ "$PHP_FLAVOUR" == "null" ]; then
  error "Could not find a PHP flavour for $OS_FLAVOUR + $SERVER_FLAVOUR + $PHP_VERSION" 2;
fi
if [ -z "${TARGET_IMAGE:+x}" ]; then
  read -ra TARGET_IMAGES <<<"$(get_target_images "$PHP_FLAVOUR" "$PS_VERSION" "$PHP_VERSION" "$OS_FLAVOUR" "$LATEST")"
else
  read -ra TARGET_IMAGES <<<"-t $TARGET_IMAGE"
fi

#if [[ "$PS_VERSION" == "nightly" ]]; then
#  TAGS="--tag $TARGET_IMAGE:nightly";
#  echo "Ready to create: $TARGET_IMAGE:nightly"
#else
#  TAGS="--tag $TARGET_IMAGE:$PS_VERSION-$PHP_FLAVOUR --tag $TARGET_IMAGE:latest";
#  echo "Ready to create: $TARGET_IMAGE:$PS_VERSION-$PHP_FLAVOUR"
#fi

# Info
# ----------------------
echo "🐳 Use $DEFAULT_DOCKER_IMAGE"
echo "Use PrestaShop $PS_VERSION with PHP $PHP_VERSION on $OS_FLAVOUR"

# Build the docker image
# ----------------------
CACHE_IMAGE=${TARGET_IMAGES[1]}
docker pull "$CACHE_IMAGE" 2> /dev/null || true
docker buildx build \
  --file "./docker/${OS_FLAVOUR}.Dockerfile" \
  --platform "${PLATFORM:-$DEFAULT_PLATFORM}" \
  --build-arg PHP_VERSION="$PHP_VERSION" \
  --build-arg PHP_FLAVOUR="$PHP_FLAVOUR" \
  --build-arg PS_VERSION="$PS_VERSION" \
  --build-arg GIT_SHA="$GIT_SHA" \
  --cache-from type=registry,ref="$CACHE_IMAGE" \
  --cache-to type=inline \
  --label org.opencontainers.image.title="PrestaShop" \
  --label org.opencontainers.image.description="PrestaShop docker image" \
  --label org.opencontainers.image.source=https://github.com/PrestaShop/docker \
  --label org.opencontainers.image.url=https://github.com/PrestaShop/docker \
  --label org.opencontainers.image.licenses=MIT \
  --label org.opencontainers.image.created="$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")" \
  "${TARGET_IMAGES[@]}" \
  "$([ "${PUSH}" == "true" ] && echo "--push" || echo "--load")" \
  .
