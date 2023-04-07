# How to use

A PrestaShop Docker tool build, tag an publish production Docker images.
See: https://hub.docker.com/r/prestashop/prestashop

## Requirements

- Docker: https://docs.docker.com/engine/install
- [jq](https://stedolan.github.io/jq/):

```bash
apt install jq
brew install jq
apk add jq
```

- (optional) BuildX to cross compile

## Build

To build a PrestaShop 8.0.1:

```sh
> PS_VERSION=8.0.1 ./build.sh --push
prestashop/prestashop:8.0.1
prestashop/prestashop:8.0.1-apache
prestashop/prestashop:8.0.1-8.1
prestashop/prestashop:8.0.1-8.1-apache
```

Available env vars:

| Env var                | Description                                                                         | Default                            |
| ---------------------- | ----------------------------------------------------------------------------------- | ---------------------------------- |
| **BUILDPLATFORM**      | [Docker multiplatform arch](https://docs.docker.com/build/building/multi-platform/) | `linux/amd64`                      |
| **LINUX_DISTRIBUTION** | `debian` or `alpine`                                                                | `debian`                           |
| **PHP_VERSION**        | [The PHP version](https://hub.docker.com/_/php)                                     | recommended version for PrestaShop |
| **PHP_FLAVOUR**        | `fpm`, `apache` or `zts`                                                            | `apache`                           |
| **PS_VERSION**         | PrestaShop version                                                                  | `latest`                           |
| **DOCKER_REPOSITORY**  | the Docker image repository                                                         | `prestashop/prestashop`            |

> Note: default debian distribution is set to Debian 11 Bullseye.

---

# WIP: Notes

## How to use

```sh
docker run --port 80:80 --detach --name prestashop prestashop/prestashop:8.0.1
```

### Exemple: je release PrestaShop "8.0.1"

| TAGS             | What's In        | Alias to         |
| ---------------- | ---------------- | ---------------- |
| 8.0.1            | apache + php 8.1 | 8.0.1-8.1-apache |
| 8.0.1-apache     | apache + php 8.1 | 8.0.1-8.1-apache |
| 8.0.1-8.1        | apache + php 8.1 | 8.0.1-8.1-apache |
| 8.0.1-8.1-apache | apache + php 8.1 | N/A              |
| 8.0.1-fpm        | fpm + php 8.1    | 8.0.1-alpine     |
| 8.0.1-8.1-fpm    | fpm + php 8.1    | 8.0.1-alpine     |
| 8.0.1-alpine     | php 8.1 + alpine | N/A              |

=> mais pas de 8.0, car la version 8.0 n'est pas recommandée.

# Images

\*\*debian\_\_: debian images are base on debian 11 Bullseye.

# Questions pour l'OSPO

|8.0.1-8.1 | apache + php 8.1|
==> Si on veut proposer uniquement les versions recommandées pour la production ça simplifie le deal.

Je publie le 01/01/2023 une 1.7.7.8 : le tag 1.7.7 et 1.7 bouge
Je publie le 02/01/2023 une 1.7.7.9 : le tag 1.7.7 et 1.7 bouge

8.0.1 => 8.0 bouge -> 8 bouge

## BuildX

```
docker run --privileged --rm tonistiigi/binfmt --install arm64,arm,amd64
docker buildx create --name multiarch --use
docker buildx build --platform linux/amd64,linux/arm64

--push to publish
```
