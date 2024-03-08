# Example: ngrok tunnel example

[Ngrok](https://ngrok.com) is a handy http tunnel you can use to expose your local environment to the Web and inspect incoming requests.

## Test the example

1. First, you will have to Sign up to your ngrok account. For this use case, the free plan is sufficient. Once it's done, on the left menu clic on "Getting Started > Your Auth token"

2. Copy this token to your own .env file (`mv .env.dist .env`)

3. Run PrestaShop alongside a Ngrok agent:

TODO: Full logs + Ngrok tunnel url

```sh
docker compose up prestashop --force-recreate
[+] Running 3/0
 ✔ Container prestashop-ngrok-tunnel-mysql-1       Running               0.0s 
 ✔ Container prestashop-ngrok-tunnel-ngrok-1       Running               0.0s 
 ✔ Container prestashop-ngrok-tunnel-prestashop-1  Recreated             0.1s 
Attaching to prestashop-1
prestashop-1  | 
prestashop-1  | * Setting up install lock file...
prestashop-1  | 
prestashop-1  | * Reapplying PrestaShop files for enabled volumes ...
prestashop-1  | 
prestashop-1  | * Copying files from tmp directory ...
prestashop-1  | 
prestashop-1  | * No pre-install script found, let's continue...
prestashop-1  | 
prestashop-1  | * No post-install script found, let's continue...
prestashop-1  | 
prestashop-1  | * Setup completed, removing lock file...
prestashop-1  | 
prestashop-1  | * Enabling DEMO mode ...
prestashop-1  | 
prestashop-1  | * Almost ! Starting web server now
prestashop-1  | 
prestashop-1  | 
prestashop-1  | * No init script found, let's continue...
```

From the logs you can guess where to connect to:

- http://4452-37-170-242-21.ngrok.app

But you will also be redirected to the public URL by PrestaShop if you make a local call to:

- http://localhost:8000
