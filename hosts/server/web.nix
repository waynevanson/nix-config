{
  config,
  ...
}:
{
  security.acme = {
    acceptTerms = true;
    defaults.email = "waynevanson@gmail.com";
    certs."waynevanson.com" = {
      group = "nginx";
      dnsProvider = "spaceship";
      webroot = null;
      credentialFiles = {
        "SPACESHIP_API_KEY_FILE" = config.sops.secrets.spaceship-client-id.path;
        "SPACESHIP_API_SECRET_FILE" = config.sops.secrets.spaceship-client-secret.path;
      };
    };
    certs."procurare.tech" = {
      group = "nginx";
      dnsProvider = "digitalocean";
      webroot = null;
      reloadServices = [ "nginx.service" ];
      credentialFiles = {
        "DO_AUTH_TOKEN_FILE" = config.sops.secrets.digitalocean-token.path;
      };
    };
  };

  services.nginx = {
    enable = true;
    virtualHosts = {
      "procurare.tech" = {
        useACMEHost = "procurare.tech";
        forceSSL = true;
        locations."/" = {
          proxyPass = "http://10.233.1.2";
          proxyWebsockets = true;
          recommendedProxySettings = true;
        };
      };
    };
  };

  networking.extraHosts = ''
    127.0.0.1 procurare.tech
    127.0.0.1 www.procurare.tech
  '';
  networking.firewall.allowedTCPPorts = [
    80
    443
  ];
}
