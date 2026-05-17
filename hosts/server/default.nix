{ config, ... }:

let
  sops' = {
    sops.secrets.spaceship-token = {
      sopsFile = ../../.sops.secrets.yaml;
      key = "spaceship/token";
    };
  };

  acme' = {
    security.acme = {
      acceptTerms = true;
      defaults.email = "waynevanson@gmail.com";
      certs."waynevanson.com" = {
        dnsProvider = "spaceship";
        credentialFiles = {
          "SPACESHIP_API_TOKEN_FILE" = config.sops.secrets.spaceship-token.path;
        };
      };
    };
  };

  nginx' = {
    services.nginx = {
      enable = true;
      virtualHosts."waynevanson.com" = {
        enableACME = true;
        forceSSL = true;
        locations."/" = {
          return = "200 'Hello from NixOS server'";
        };
      };
    };

    networking.firewall.allowedTCPPorts = [
      80
      443
    ];
  };

  ssh' = {
    services.ssh = {
      enable = true;
    };
  };
in
{
  imports = [
    sops'
    acme'
    nginx'
    ssh'
  ];
}
