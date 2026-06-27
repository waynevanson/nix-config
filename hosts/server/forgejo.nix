{ config, lib, pkgs, self, ... }:
let
  catppuccinThemes = self.packages.${pkgs.stdenv.hostPlatform.system}.catppuccin-forgejo-themes;
in
{
  security.acme.certs."waynevanson.com".extraDomainNames = [ "git.waynevanson.com" ];
  sops.secrets.postgres-password.key = "postgres/password";
  services = {
    forgejo = {
      enable = true;
      database = {
        type = "postgres";
        host = "localhost";
        port = 5432;
        name = "forgejo";
        user = "forgejo";
        passwordFile = config.sops.secrets.postgres-password.path;
      };
      lfs.enable = true;
      # https://forgejo.org/docs/latest/admin/config-cheat-sheet/
      settings = {
        server = {
          DOMAIN = "git.waynevanson.com";
          ROOT_URL = "https://git.waynevanson.com/";
          HTTP_PORT = 3098;
          SSH_PORT = lib.head config.services.openssh.ports;
        };
        service = {
          DISABLE_REGISTRATION = true;
        };
        actions = {
          ENABLED = true;
        };
        ui = {
          THEMES = "catppuccin-latte-mauve,catppuccin-mocha-mauve,catppuccin-mauve-auto,forgejo-auto,forgejo-light,forgejo-dark";
          DEFAULT_THEME = "catppuccin-mauve-auto";
        };
      };
    };
    postgresql = {
      enable = true;
      ensureDatabases = [ "forgejo" ];
      ensureUsers = [
        {
          name = "forgejo";
          # maybe not?
          ensureDBOwnership = true;
        }
      ];
    };
    nginx.virtualHosts."git.waynevanson.com" = {
      useACMEHost = "waynevanson.com";
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://localhost:3098";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
        '';
      };
    };
  };

  systemd.tmpfiles.rules = lib.mkAfter [
    "L+ ${config.services.forgejo.customDir}/public/assets/css 0750 ${config.services.forgejo.user} ${config.services.forgejo.group} - ${catppuccinThemes}/share/forgejo/public/assets/css"
  ];
}
