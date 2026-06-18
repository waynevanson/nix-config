{ config, ... }:
{
  sops.secrets.digitalocean-token = {
    key = "digitalocean/token";
  };

  security.acme.certs."luscomberecords.com" = {
    dnsProvider = "digitalocean";
    webroot = null;
    extraDomainNames = [ "www.luscomberecords.com" ];
    group = "nginx";
    credentialFiles = {
      "DO_AUTH_TOKEN_FILE" = config.sops.secrets.digitalocean-token.path;
    };
    reloadServices = [ "nginx.service" ];
  };

  custom.services.wordpress.instances."luscomberecords.com" = {
    acmeHost = "luscomberecords.com";
  };

  networking.extraHosts = ''
    127.0.0.1 luscomberecords.com
    127.0.0.1 www.luscomberecords.com
  '';
}
