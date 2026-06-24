{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.custom.services.wordpress;
  wordpress = pkgs.stdenvNoCC.mkDerivation {
    pname = "wordpress-with-themes";
    version = pkgs.wordpress.version;
    dontUnpack = true;
    installPhase = ''
      mkdir -p $out
      cp -r ${pkgs.wordpress}/* $out/
      chmod -R u+w $out/share/wordpress/wp-content
      mkdir -p $out/share/wordpress/wp-content/themes
      cp -r ${pkgs.wordpressPackages.themes.twentytwentyfive} $out/share/wordpress/wp-content/themes/twentytwentyfive
    '';
  };
  userFor = domain: "wordpress-${replaceStrings [ "." ] [ "-" ] domain}";
  dbFor = domain: "wordpress_${replaceStrings [ "." ] [ "_" ] domain}";
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
        define('DB_CHARSET', 'utf8mb4');
        define('DB_COLLATE', ''');

        $table_prefix = 'wp_';

        require_once('${secretKeys}');

        define('WP_HOME', 'https://${domain}');
        define('WP_SITEURL', 'https://${domain}');
        define('FORCE_SSL_ADMIN', true);
        define('FS_METHOD', 'direct');

        if ( !defined('ABSPATH') )
          define('ABSPATH', '${root}/');

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
      type = types.attrsOf (
        types.submodule {
          options = {
            acmeHost = mkOption {
              type = types.str;
              description = ''
                ACME certificate host to use for HTTPS.
                The certificate must be defined separately via `security.acme`.
              '';
            };
          };
        }
      );
      default = {
      };
      description = "Mutable WordPress instances to host.";
    };
  };
  config =
    mkIf
      (
        cfg.instances != {
        }
      )
      {
        services = {
          mysql = {
            enable = true;
            package = pkgs.mariadb;
            ensureDatabases = map (i: i.db) instances;
            ensureUsers = map (i: {
              name = i.user;
              ensurePermissions = {
                "${i.db}.*" = "ALL PRIVILEGES";
              };
            }) instances;
          };
          nginx = {
            enable = true;
            virtualHosts = listToAttrs (
              map (
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
              ) instances
            );
          };
          fail2ban = {
            enable = true;
            jails = {
              wordpress-wplogin = {
                settings = {
                  backend = "auto";
                  logpath = "/var/log/nginx/access.log";
                  port = "http,https";
                  maxretry = 10;
                  findtime = 300;
                  bantime = 3600;
                };
                filter = {
                  Definition = {
                    failregex = ''^<HOST> .* "POST /wp-login\.php HTTP/[0-9.]+"'';
                  };
                };
              };
              wordpress-xmlrpc = {
                settings = {
                  backend = "auto";
                  logpath = "/var/log/nginx/access.log";
                  port = "http,https";
                  maxretry = 10;
                  findtime = 300;
                  bantime = 3600;
                };
                filter = {
                  Definition = {
                    failregex = ''^<HOST> .* "POST /xmlrpc\.php HTTP/[0-9.]+"'';
                  };
                };
              };
              nginx-badbots = {
                settings = {
                  backend = "auto";
                  filter = "apache-badbots";
                  logpath = "/var/log/nginx/access.log";
                  port = "http,https";
                  maxretry = 2;
                  findtime = 60;
                  bantime = 86400;
                };
              };
            };
          };
          phpfpm.pools = listToAttrs (
            map (
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
                  open_basedir = "${instance.root}:/var/lib/wordpress/${instance.domain}:/tmp:/run/mysqld"
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
            ) instances
          );
        };
        environment.systemPackages = [ pkgs.wp-cli ];
        users.users = listToAttrs (
          map (
            instance:
            nameValuePair instance.user {
              isSystemUser = true;
              group = config.services.nginx.group;
              home = "/var/lib/wordpress/${instance.domain}";
              createHome = true;
              homeMode = "750";
            }
          ) instances
        );
        systemd.services = listToAttrs (
          map (
            instance:
            nameValuePair "wordpress-${replaceStrings [ "." ] [ "-" ] instance.domain}-setup" {
              description = "Set up mutable WordPress instance for ${instance.domain}";
              serviceConfig = {
                Type = "oneshot";
                RemainAfterExit = true;
              };
              wantedBy = [ "multi-user.target" ];
              before = [ "phpfpm-wordpress-${instance.domain}.service" ];
              after = [
                "systemd-tmpfiles-setup.service"
                "mysql.service"
              ];
              script = ''
                store="${wordpress}/share/wordpress"
                root="${instance.root}"
                secretKeys="${instance.secretKeys}"

                mkdir -p "$root"

                # Copy/update WordPress core, preserving mutable wp-content.
                for item in "$store"/*; do
                  name=$(basename "$item")
                  if [ "$name" = "wp-content" ]; then
                    continue
                  fi
                  if [ -d "$item" ]; then
                    rm -rf "$root/$name"
                    cp -r "$item" "$root/$name"
                  else
                    cp -f "$item" "$root/$name"
                  fi
                done

                # Seed wp-content on first install.
                if [ ! -e "$root/wp-content" ]; then
                  cp -r "$store/wp-content" "$root/wp-content"
                fi

                # Seed default theme if none present.
                if [ ! -d "$root/wp-content/themes/twentytwentyfive" ]; then
                  mkdir -p "$root/wp-content/themes"
                  cp -r "$store/wp-content/themes/twentytwentyfive" "$root/wp-content/themes/"
                fi

                mkdir -p "$root/wp-content/upgrade" "$root/wp-content/uploads"
                chmod -R u+w "$root/wp-content"

                if [ ! -e "$secretKeys" ]; then
                  umask 0177
                  echo "<?php" > "$secretKeys"
                  for var in AUTH_KEY SECURE_AUTH_KEY LOGGED_IN_KEY NONCE_KEY AUTH_SALT SECURE_AUTH_SALT LOGGED_IN_SALT NONCE_SALT; do
                    echo "define('$var', '$(${pkgs.openssl}/bin/openssl rand -base64 64)');" >> "$secretKeys"
                  done
                  echo "?>" >> "$secretKeys"
                  chmod 440 "$secretKeys"
                fi

                rm -f "$root/wp-config.php"
                cp -f "${instance.wpConfig}" "$root/wp-config.php"

                chown -R ${instance.user}:${config.services.nginx.group} "$root"
                chown ${instance.user}:${config.services.nginx.group} "$secretKeys"
              '';
            }
          ) instances
        );
      };
}
