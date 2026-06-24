# nix binary cache server
{
  config,
  ...
}:
let
  port = "2884";
in
{
  security.acme.certs."waynevanson.com".extraDomainNames = [ "atticd.waynevanson.com" ];
  sops.templates.atticd-environment-file = {
    content = ''
      ATTIC_SERVER_TOKEN_RS256_SECRET_BASE64=${config.sops.placeholder.atticd-secret}
      AWS_ACCESS_KEY_ID=${config.sops.placeholder.garage-access-key}
      AWS_SECRET_ACCESS_KEY=${config.sops.placeholder.garage-secret-key}
    '';
    owner = "atticd";
  };
  users = {
    groups.atticd = {
    };
    users.atticd = {
      isSystemUser = true;
      group = "atticd";
    };
  };
  services = {
    atticd = {
      enable = true;
      environmentFile = config.sops.templates.atticd-environment-file.path;
      settings = {
        jwt = {
        };
        listen = "[::]:${port}";
        storage = {
          type = "s3";
          region = "garage";
          bucket = "attic";
          endpoint = "https://s3.garage.waynevanson.com";
        };
      };
    };
    nginx.virtualHosts."atticd.waynevanson.com" = {
      useACMEHost = "waynevanson.com";
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://localhost:${port}";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_max_temp_file_size 0;
          client_max_body_size 0;
        '';
      };
    };
  };
}
