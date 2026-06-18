{ config, pkgs, ... }:
let
  host = "waynevanson.com";
in
{
  sops.secrets.digitalocean-token = {
    key = "digitalocean/token";
  };

  services.wordpress = {
    webserver = "nginx";
    sites.${host} = {
      database = {
        createLocally = true;
        socket = "/run/mysqld/mysqld.sock";
      };
      poolConfig = {
        "pm" = "dynamic";
        "pm.max_children" = 16;
        "pm.start_servers" = 2;
        "pm.min_spare_servers" = 2;
        "pm.max_spare_servers" = 4;
        "pm.max_requests" = 500;
      };
      settings = {
        WP_HOME = "https://${host}";
        WP_SITEURL = "https://${host}";
        FORCE_SSL_ADMIN = true;
      };
    };
  };

  services.phpfpm.pools."wordpress-${host}".phpOptions = ''
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

  services.nginx.virtualHosts.${host} = {
    # useACMEHost = host;
    forceSSL = true;
    serverAliases = [ "www.${host}" ];
    extraConfig = ''
      client_max_body_size 64m;
    '';
  };

  networking.extraHosts = ''
    127.0.0.1 ${host}
    127.0.0.1 www.${host}
  '';

  environment.systemPackages = with pkgs; [ wp-cli ];
}
