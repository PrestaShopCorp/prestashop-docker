#!/bin/bash
set -e
cd "$(dirname "$0")"

# Available variables
# -------------------
declare PS_VERSION;      # -- PrestaShop version, defaults to latest
declare PHP_VERSION;     # -- PHP version, defaults to recommended version for PrestaShop
declare OS_FLAVOUR;      # -- either "alpine" or "debian" (default)
declare SERVER_FLAVOUR;  # -- either "apache" (default), "fpm" (no web server) or "nginx"
declare TARGET_PLATFORM; # -- a comma separated list of target platforms (defaults to your operating system)
declare PLATFORM;        # -- alias for $TARGET_PLATFORM
declare TARGET_IMAGE;    # -- docker image name, defaults to "prestashop/prestashop"
declare PUSH;            # -- set it to "true" if you want to push the resulting image
declare ZIP_SOURCE;      # -- the zip to unpack in PrestaShop
declare DRY_RUN;         # -- if used, won't really build the image. Useful to check tags compliance

# Static configuration
# --------------------
DEFAULT_OS="debian";
DEFAULT_SERVER="apache";
DEFAULT_DOCKER_IMAGE=prestashop/prestashop
DEFAULT_PLATFORM=$(docker system info --format '{{.OSType}}/{{.Architecture}}')
GIT_SHA=$(git rev-parse HEAD)
TARGET_PLATFORM="${TARGET_PLATFORM:-${PLATFORM:-$DEFAULT_PLATFORM}}"
PRESTASHOP_TAGS=$(git ls-remote --tags git@github.com:PrestaShop/PrestaShop.git | cut -f2 | grep -Ev '\/1.5|\/1.6.0|alpha|beta|rc|RC|\^' | cut -d '/' -f3 | sort -r -V)
#PRESTASHOP_MAJOR_TAGS=$(get_prestashop_major_tags)
PRESTASHOP_MINOR_TAGS=$(get_prestashop_minor_tags)
error() {
  echo -e "\e[1;31m${1:-Unknown error}\e[0m"
  exit "${2:-1}"
}

get_latest_prestashop_version() {
  curl --silent --show-error --fail --location --request GET \
    'https://api.github.com/repos/prestashop/prestashop/releases/latest' | jq -r '.tag_name'
}

get_prestashop_minor_tags() {
  while IFS= read -r version; do
    major_minor=$(echo "$version" | cut -d. -f1-2)
    major_minor_patch=$(echo "$version" | cut -d. -f1-3)
    criteria=$major_minor
    # shellcheck disable=SC3010
    [[ "$major_minor" == 1* ]] && criteria=$major_minor_patch
    if ! grep -q "^$criteria" "$PRESTASHOP_MINOR_TAGS"; then
      echo "$version" >> "$PRESTASHOP_MINOR_TAGS"
    fi
  done < "$PRESTASHOP_TAGS"
}


is_version_latest_major_version() {
  X_VERSION=$(echo "$1" | cut -d. -f1)
  echo $X_VERSION
}

is_version_latest_minor_version() {
  XY_VERSION=$(echo "$1" | cut -d. -f1-2)
#  RES=$(echo $PRESTASHOP_TAGS | awk -F. '!seen[$1"."$2]++' | grep -x "$XY_VERSION")
  echo $XY_VERSION
}

get_prestashop_tags() {
  git ls-remote --tags git@github.com:PrestaShop/PrestaShop.git \
  | cut -f2 \
  | grep -Ev '\/1.5|\/1.6.0|alpha|beta|rc|RC|\^' \
  | cut -d '/' -f3 \
  | sort -r -V > "$PRESTASHOP_TAGS"
}

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
   jq -r '."'"${PHP_VERSION}"'"."'"${OS_FLAVOUR}"'".'"${SERVER_FLAVOUR}" < php-flavours.json;
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
# * php-8.2
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
  if [ "$PS_VERSION" == "nightly" ]; then
      if [ "$OS_FLAVOUR" = "$DEFAULT_OS" ]; then
        RES="-t ${DEFAULT_DOCKER_IMAGE}:nightly";
      fi
      RES="${RES} -t ${DEFAULT_DOCKER_IMAGE}:nightly-${OS_FLAVOUR}";
  else
    if [ "$PS_VERSION" = "$(get_latest_prestashop_version)" ] && [ "$OS_FLAVOUR" = "$DEFAULT_OS" ] && [ "$PHP_VERSION" = "$(get_recommended_php_version "$PS_VERSION")" ]; then
      RES="-t ${DEFAULT_DOCKER_IMAGE}:latest";
    fi
    if [ "$OS_FLAVOUR" = "$DEFAULT_OS" ]; then
      RES="${RES} -t ${DEFAULT_DOCKER_IMAGE}:${PS_VERSION}-${PHP_VERSION}";
      if [ "$PHP_VERSION" = "$(get_recommended_php_version "$PS_VERSION")" ]; then
        RES="${RES} -t ${DEFAULT_DOCKER_IMAGE}:${PS_VERSION}";
        RES="${RES} -t ${DEFAULT_DOCKER_IMAGE}:php-${PHP_VERSION}";
        # If the x.y.z version of PrestaShop is the latest version of the major

      fi
    fi
    RES="${RES} -t ${DEFAULT_DOCKER_IMAGE}:${PS_VERSION}-${PHP_FLAVOUR}";
    RES="${RES} -t ${DEFAULT_DOCKER_IMAGE}:${PS_VERSION}-${OS_FLAVOUR}";
  fi
  echo "--------------> $(is_version_latest_minor_version "8.1.7")";
  echo "--------------> $(is_version_latest_minor_version "8.1.6")";
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
  read -ra TARGET_IMAGES <<<"$(get_target_images "$PHP_FLAVOUR" "$PS_VERSION" "$PHP_VERSION" "$OS_FLAVOUR")"
else
  read -ra TARGET_IMAGES <<<"-t $TARGET_IMAGE"
fi

if [ "$PS_VERSION" == "nightly" ]; then
  ZIP_SOURCE="https://storage.googleapis.com/prestashop-core-nightly/nightly.zip"
else
  ZIP_SOURCE="https://github.com/PrestaShop/PrestaShop/releases/download/${PS_VERSION}/prestashop_${PS_VERSION}.zip"
fi

# Build the docker image
# ----------------------
CACHE_IMAGE=${TARGET_IMAGES[1]}
if [ -n "${DRY_RUN}" ]; then
  docker() {
    echo docker "$@"
  }
fi
docker pull "$CACHE_IMAGE" 2> /dev/null || true
docker buildx build \
  --progress=plain \
  --file "./docker/${OS_FLAVOUR}.Dockerfile" \
  --platform "$TARGET_PLATFORM" \
  --cache-from type=registry,ref="$CACHE_IMAGE" \
  --cache-to type=inline \
  --build-arg PHP_FLAVOUR="$PHP_FLAVOUR" \
  --build-arg SERVER_FLAVOUR="$SERVER_FLAVOUR" \
  --build-arg PS_VERSION="$PS_VERSION" \
  --build-arg PHP_VERSION="$PHP_VERSION" \
  --build-arg GIT_SHA="$GIT_SHA" \
  --build-arg ZIP_SOURCE="$ZIP_SOURCE" \
  --label org.opencontainers.image.title="PrestaShop" \
  --label org.opencontainers.image.description="PrestaShop official docker image" \
  --label org.opencontainers.image.source=https://github.com/PrestaShop/docker \
  --label org.opencontainers.image.url=https://hub.docker.com/r/prestashop/prestashop \
  --label org.opencontainers.image.licenses=MIT \
  --label org.opencontainers.image.created="$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")" \
  "${TARGET_IMAGES[@]}" \
  "$([ "${PUSH}" == "true" ] && echo "--push" || echo "--load")" \
  .
