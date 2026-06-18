{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.custom.services.wordpress;

  userFor = domain: "wordpress-${replaceStrings ["."] ["-"] domain}";
  dbFor = domain: "wordpress_${replaceStrings ["."] ["_"] domain}";

  rootFor = domain: "/var/lib/wordpress/${domain}/wordpress";
  secretKeysFor = domain: "/var/lib/wordpress/${domain}/secret-keys.php";

  mkWpConfig =
    domain: icfg:
    let
      user = userFor domain;
      db = dbFor domain;
      root = rootFor domain;
      secretKeys = secretKeysFor domain;
    in
    pkgs.writeTextFile {
      name = "wp-config-${domain}.php";
      text = ''
        <?php
        define('DB_NAME', '${db}');
        define('DB_USER', '${user}');
        define('DB_PASSWORD', ''');
        define('DB_HOST', 'localhost:/run/mysqld/mysqld.sock');
        define('DB_CHARSET', 'utf8');
        define('DB_COLLATE', ''');

        $table_prefix = 'wp_';

        require_once('${secretKeys}');

        define('WP_HOME', 'https://${domain}');
        define('WP_SITEURL', 'https://${domain}');
        define('FORCE_SSL_ADMIN', true);
        define('FS_METHOD', 'direct');

        if ( !defined('ABSPATH') )
          define('ABSPATH', dirname(__FILE__) . '/');

        require_once(ABSPATH . 'wp-settings.php');
        ?>
      '';
      checkPhase = "${pkgs.php}/bin/php --syntax-check $target";
    };

  instances = mapAttrsToList (domain: icfg: {
    inherit domain icfg;
    user = userFor domain;
    db = dbFor domain;
    root = rootFor domain;
    secretKeys = secretKeysFor domain;
    wpConfig = mkWpConfig domain icfg;
  }) cfg.instances;
in
{
  options.custom.services.wordpress = {
    instances = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          acmeHost = mkOption {
            type = types.str;
            description = ''
              ACME certificate host to use for HTTPS.
              The certificate must be defined separately via `security.acme`.
            '';
          };
        };
      });
      default = { };
      description = "Mutable WordPress instances to host.";
    };
  };

  config = mkIf (cfg.instances != { }) {
    services.mysql = {
      enable = true;
      package = pkgs.mariadb;
    };
    services.nginx.enable = true;

    environment.systemPackages = [ pkgs.wp-cli ];

    users.users = listToAttrs (map (
      instance:
      nameValuePair instance.user {
        isSystemUser = true;
        group = config.services.nginx.group;
        home = "/var/lib/wordpress/${instance.domain}";
        createHome = true;
      }
    ) instances);

    services.mysql = {
      ensureDatabases = map (i: i.db) instances;
      ensureUsers = map (
        i:
        {
          name = i.user;
          ensurePermissions = {
            "${i.db}.*" = "ALL PRIVILEGES";
          };
        }
      ) instances;
    };

    systemd.services = listToAttrs (map (
      instance:
      nameValuePair "wordpress-${replaceStrings ["."] ["-"] instance.domain}-setup" {
        description = "Set up mutable WordPress instance for ${instance.domain}";
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        wantedBy = [ "multi-user.target" ];
        before = [ "phpfpm-wordpress-${instance.domain}.service" ];
        after = [ "systemd-tmpfiles-setup.service" ];
        script = ''
          store="${pkgs.wordpress}/share/wordpress"
          root="${instance.root}"
          secretKeys="${instance.secretKeys}"

          if [ ! -e "$root/index.php" ]; then
            mkdir -p "$root"
            cp -r "$store"/. "$root"/
            mkdir -p "$root/wp-content/upgrade"
          fi

          if [ ! -e "$secretKeys" ]; then
            umask 0177
            echo "<?php" > "$secretKeys"
            for var in AUTH_KEY SECURE_AUTH_KEY LOGGED_IN_KEY NONCE_KEY AUTH_SALT SECURE_AUTH_SALT LOGGED_IN_SALT NONCE_SALT; do
              echo "define('$var', '$(${pkgs.openssl}/bin/openssl rand -base64 64)');" >> "$secretKeys"
            done
            echo "?>" >> "$secretKeys"
            chmod 440 "$secretKeys"
          fi

          ln -sf "${instance.wpConfig}" "$root/wp-config.php"

          chown -R ${instance.user}:${config.services.nginx.group} "$root"
          chown ${instance.user}:${config.services.nginx.group} "$secretKeys"
        '';
      }
    ) instances);

    services.phpfpm.pools = listToAttrs (map (
      instance:
      nameValuePair "wordpress-${instance.domain}" {
        user = instance.user;
        group = config.services.nginx.group;
        phpOptions = ''
          memory_limit = 512M
          upload_max_filesize = 64M
          post_max_size = 64M
          max_execution_time = 300
          max_input_vars = 3000
          opcache.memory_consumption = 128
          opcache.interned_strings_buffer = 16
          opcache.max_accelerated_files = 10000
          opcache.revalidate_freq = 60
          open_basedir = "${instance.root}:/tmp:/run/mysqld"
        '';
        settings = {
          "listen.owner" = config.services.nginx.user;
          "listen.group" = config.services.nginx.group;
          "pm" = "dynamic";
          "pm.max_children" = 16;
          "pm.start_servers" = 2;
          "pm.min_spare_servers" = 2;
          "pm.max_spare_servers" = 4;
          "pm.max_requests" = 500;
        };
      }
    ) instances);

    services.nginx.virtualHosts = listToAttrs (map (
      instance:
      nameValuePair instance.domain {
        serverName = instance.domain;
        serverAliases = [ "www.${instance.domain}" ];
        useACMEHost = instance.icfg.acmeHost;
        forceSSL = true;
        root = instance.root;
        extraConfig = ''
          index index.php;
          client_max_body_size 64m;
        '';
        locations = {
          "/" = {
            priority = 200;
            extraConfig = ''
              try_files $uri $uri/ /index.php$is_args$args;
            '';
          };
          "~ \\.php$" = {
            priority = 500;
            extraConfig = ''
              try_files $uri =404;
              fastcgi_split_path_info ^(.+\.php)(/.+)$;
              fastcgi_pass unix:${config.services.phpfpm.pools."wordpress-${instance.domain}".socket};
              fastcgi_index index.php;
              include "${config.services.nginx.package}/conf/fastcgi.conf";
              fastcgi_param PATH_INFO $fastcgi_path_info;
              fastcgi_param PATH_TRANSLATED $document_root$fastcgi_path_info;
              fastcgi_param HTTP_PROXY "";
              fastcgi_intercept_errors off;
              fastcgi_buffer_size 16k;
              fastcgi_buffers 4 16k;
              fastcgi_connect_timeout 300;
              fastcgi_send_timeout 300;
              fastcgi_read_timeout 300;
            '';
          };
          "~ /\\." = {
            priority = 800;
            extraConfig = "deny all;";
          };
          "~* /(?:uploads|files)/.*\\.php$" = {
            priority = 900;
            extraConfig = "deny all;";
          };
          "~* \\.(js|css|png|jpg|jpeg|gif|ico)$" = {
            priority = 1000;
            extraConfig = ''
              expires max;
              log_not_found off;
            '';
          };
        };
      }
    ) instances);
  };
}
