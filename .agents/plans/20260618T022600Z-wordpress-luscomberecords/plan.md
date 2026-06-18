# Add WordPress for luscomberecords.com to hosts/server

Created: 2026-06-18T02:26:00Z

## Goal

Deploy a WordPress site on the NixOS server host, served at `https://luscomberecords.com`, backed by a local MariaDB database, with TLS certificates obtained via ACME DNS-01 through DigitalOcean DNS.

## Context

- The server configuration lives in `hosts/server/default.nix`.
- Nginx is already enabled and serves other virtual hosts; ACME is configured via `security.acme` using the `spaceship` DNS provider for `waynevanson.com`.
- Secrets are managed with `sops-nix`; the shared secrets file is `.sops.secrets.yaml` and secret bindings are declared in `modules/sops.nix`.
- The existing `services.wordpress` NixOS module can provision the site, PHP-FPM pool, nginx vhost, and MariaDB database/user automatically when `database.createLocally = true`.
- DigitalOcean DNS-01 ACME requires a `DO_AUTH_TOKEN_FILE` credential file.

## Tasks

- [ ] **Add DigitalOcean token secret placeholder**
  - Add a `digitalocean.token` entry to `.sops.secrets.yaml`.
  - Use a placeholder value initially; the real token will be inserted later.
  - Example command:
    ```sh
    sops set '.sops.secrets.yaml' '["digitalocean"]["token"]' '"PLACEHOLDER_DO_TOKEN"'
    ```

- [ ] **Bind the DigitalOcean secret in sops-nix**
  - In `modules/sops.nix`, add:
    ```nix
    digitalocean-token.key = "digitalocean/token";
    ```

- [ ] **Create `hosts/server/wordpress.nix`**
  - Create the file with the following content (adjust `database.socket` and site URL as needed):
    ```nix
    { config, ... }:
    {
      sops.secrets.digitalocean-token.key = "digitalocean/token";

      security.acme.certs."luscomberecords.com" = {
        dnsProvider = "digitalocean";
        extraDomainNames = [ "www.luscomberecords.com" ];
        credentialFiles = {
          "DO_AUTH_TOKEN_FILE" = config.sops.secrets.digitalocean-token.path;
        };
        reloadServices = [ "nginx.service" ];
      };

      services.wordpress = {
        webserver = "nginx";
        sites."luscomberecords.com" = {
          database = {
            createLocally = true;
            socket = "/run/mysqld/mysqld.sock";
          };
          settings = {
            WP_HOME = "https://luscomberecords.com";
            WP_SITEURL = "https://luscomberecords.com";
            FORCE_SSL_ADMIN = true;
          };
        };
      };

      services.nginx.virtualHosts."luscomberecords.com" = {
        useACMEHost = "luscomberecords.com";
        forceSSL = true;
        serverAliases = [ "www.luscomberecords.com" ];
      };

      networking.extraHosts = ''
        127.0.0.1 luscomberecords.com
        127.0.0.1 www.luscomberecords.com
      '';
    }
    ```

- [ ] **Import the new module in the server host**
  - In `hosts/server/default.nix`, add `./wordpress.nix` to the `imports` list.

- [ ] **Configure DigitalOcean DNS**
  - Ensure the `luscomberecords.com` zone is hosted on DigitalOcean and its nameservers are delegated to DigitalOcean.
  - Add A records (and AAAA if applicable) for both `luscomberecords.com` and `www.luscomberecords.com` pointing to the server public IP.

- [ ] **Replace the placeholder token with the real secret**
  - Once the DigitalOcean API token is available, update `.sops.secrets.yaml`:
    ```sh
    sops set '.sops.secrets.yaml' '["digitalocean"]["token"]' '"<REAL_DIGITALOCEAN_API_TOKEN>"'
    ```

- [ ] **(Optional) Apply PHP fine-tuning**
  - Choose the tuning options you want and add them to `hosts/server/wordpress.nix`.
  - Commonly useful settings for WordPress:
    - **PHP-FPM process manager:** adjust `pm`, `pm.max_children`, `pm.start_servers`, etc. via `services.wordpress.sites."luscomberecords.com".poolConfig`.
    - **php.ini directives:** override `services.phpfpm.pools."wordpress-luscomberecords.com".phpOptions`, e.g.
      ```nix
      services.phpfpm.pools."wordpress-luscomberecords.com".phpOptions = ''
        memory_limit = 512M
        upload_max_filesize = 64M
        post_max_size = 64M
        max_execution_time = 300
        max_input_vars = 3000
        opcache.memory_consumption = 128
        opcache.interned_strings_buffer = 16
        opcache.max_accelerated_files = 10000
        opcache.revalidate_freq = 60
      '';
      ```
    - **Nginx upload limit / timeouts:** extend `services.nginx.virtualHosts."luscomberecords.com".locations."/".extraConfig` or add `extraConfig` at the vhost level, e.g. `client_max_body_size 64m;`.
    - **PHP version:** switch the pool to `pkgs.php84` (or another supported version) via `services.phpfpm.pools."wordpress-luscomberecords.com".phpPackage`.
    - **Caching layers:** add Redis/`services.redis` with an object-cache plugin, or a page-caching plugin, for higher-traffic sites.

- [ ] **Validate and deploy**
  - Run `nix flake check`.
  - Deploy the server with the existing flake app, e.g.:
    ```sh
    nix run .#server switch
    ```
  - Or via `nixos-rebuild`:
    ```sh
    nixos-rebuild switch --flake .#server --target-host waynevanson@waynevanson.com --build-host waynevanson@waynevanson.com --sudo
    ```

- [ ] **Verify the deployment**
  - Check ACME certificate issuance:
    ```sh
    journalctl -u acme-order-renew-luscomberecords.com -e
    ```
  - Check WordPress PHP-FPM pool:
    ```sh
    journalctl -u phpfpm-wordpress-luscomberecords.com -e
    ```
  - Check MariaDB access from the `wordpress` user:
    ```sh
    sudo -u wordpress mysql -u wordpress -S /run/mysqld/mysqld.sock wordpress
    ```
  - Browse to `https://luscomberecords.com` and complete the WordPress install wizard.

## Pending Questions

- Which PHP tuning options should be applied from the start? A reasonable default baseline is:
  - `memory_limit = 512M`
  - `upload_max_filesize = 64M` / `post_max_size = 64M`
  - `max_execution_time = 300`
  - `max_input_vars = 3000`
  - OPcache with 128 MB and tuned file limits
  - Nginx `client_max_body_size 64m`
- Should the PHP-FPM pool use a higher process limit (e.g. `pm.max_children = 16`) from the start?
- Are there any specific WordPress plugins or themes to install (besides the default `twentytwentyfive` theme)?
