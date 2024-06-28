# Example: basic example

This example runs the latest available image of PrestaShop (debian with apache by default).

## Test this example

The expected output of this example is:

```sh
docker compose up prestashop --force-recreate
[+] Running 3/3
 ✔ Network prestashop-demo-example_default         Created                                                                                                                                                                             0.1s 
 ✔ Container prestashop-demo-example-mysql-1       Created                                                                                                                                                                             0.0s 
 ✔ Container prestashop-demo-example-prestashop-1  Created                                                                                                                                                                             0.0s 
Attaching to prestashop-1
prestashop-1  | 
prestashop-1  | * Setting up install lock file...
prestashop-1  | 
prestashop-1  | * Reapplying PrestaShop files for enabled volumes ...
prestashop-1  | 
prestashop-1  | * No pre-install script found, let's continue...
prestashop-1  | 
prestashop-1  | * No post-install script found, let's continue...
prestashop-1  | 
prestashop-1  | * Setup completed, removing lock file...
prestashop-1  | 
prestashop-1  | * Enabling DEMO mode ...
prestashop-1  | 
prestashop-1  | * Almost! Starting web server now
prestashop-1  | 
prestashop-1  | 
prestashop-1  | * No init script found, let's continue...
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