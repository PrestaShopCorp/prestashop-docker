# How to use

A PrestaShop Docker tool build, tag an publish production Docker images.
See: https://hub.docker.com/r/prestashop/prestashop

## Requirements

- Docker: https://docs.docker.com/engine/install

## Build

To build a PrestaShop 8.0 with PHP 8.1 apache2 and debian bullesye:

```sh
docker build \
  --build-arg PHP_TAG=8.1-rc-apache-buster \
  --build-arg PS_VERSION=8.0 \
  --tag=prestashop/prestashop:8.0-apache2
  -f docker/debian-base.Dockerfile \
  .
```

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
