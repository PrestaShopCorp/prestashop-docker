#/bin/sh
set -e -x

function get_latest_prestashop_version {
  curl 'http://github.com/prestashop/prestashop/blablabla'
}

function get_recommended_php_version {
  PS_VERSION=$0
  return cat prestashop-versions.json | jq -r '.["'$PS_VERSION'"].php.recommended';
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


TAGS=$(get_tag_aliases $PS_VERSION $PS)

docker build \
  -f docker/${LINUX_DISTRIBUTION}-base.Dockerfile \
  --build-arg PHP_DOCKER_TAG=${PHP_DOCKER_TAG} \
  --build-arg PS_VERSION=${PS_VERSION} \
  $TAGS \
  .