# Example: fpm example

This example runs the latest available image of PrestaShop with fpm (with a nginx configuration).

## Test this example

The expected output of this example is:

```sh
docker compose up prestashop --force-recreate

```

You can access to PrestaShop in your browser:
- http://localhost:8000

## Running phpMyAdmin

If you want to start a phpMyAdmin instance, it can be done easily like so:

```sh
docker compose up
# or "docker compose up prestashop php-my-admin"
```

You can now access phpMyAdmin at http://localhost:6060
