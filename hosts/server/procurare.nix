{ config, pkgs, ... }:
{

  security.acme.certs."procurare.tech" = {
    group = "nginx";
    dnsProvider = "digitalocean";
    webroot = null;
    reloadServices = [ "nginx.service" ];
    extraLegoFlags = [ "--dns.propagation-disable-ans" ];
    credentialFiles = {
      "DO_AUTH_TOKEN_FILE" = config.sops.secrets.digitalocean-token.path;
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

  containers.procurare = {
    autoStart = true;
    privateNetwork = true;
    hostAddress = "10.233.1.1";
    localAddress = "10.233.1.2";
    config =
      {
        pkgs,
        ...
      }:
      {
        system.stateVersion = "26.05";

        networking.firewall.allowedTCPPorts = [ 80 ];

        services.nginx = {
          enable = true;
          virtualHosts."procurare" = {
            default = true;
            root = pkgs.writeTextDir "index.html" "Hello, world!";
            locations."/" = {
              index = "index.html";
            };
          };
        };
      };
  };
}
