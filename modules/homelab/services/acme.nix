# todo: DNS level? sops-nix to hold secrets from spaceship
# todo: a service
{
  config,
  lib,
  ...
}: let
  config' = config.homelab.services.acme;
  certs = "/var/lib/acme/waynevanson.com";
  domain = "waynevanson.com";
  # Apply certs to all virtual hosts
  virtualHostDefaults = {
    addSSL = true;
    sslCertificateKey = "${certs}/key.pem";
    sslCertificate = "${certs}/cert.pem";
  };
  secretPath = "spaceship.env";
  token = "spaceship/token";
in {
  options.homelab.services.acme = {
    enable = lib.mkEnableOption {};
  };

  config = lib.mkIf config'.enable {
    # /var/lib/acme/.challenges must be writable by the ACME user
    # and readable by the Nginx user. The easiest way to achieve
    # this is to add the Nginx user to the ACME group.
    users.users.nginx.extraGroups = ["acme"];

    # Allow Nginx to listen to
    services.nginx.virtualHosts = {
      "${domain}" = virtualHostDefaults;
    };

    # having trouble reading these files...

    sops.secrets.${token} = {
      owner = "nginx";
      group = "nginx";
    };

    sops.templates.${secretPath} = {
      content = ''
        SPACESHIP_API_KEY=ka3Ec2FcvBmwagXS27QA
        SPACESHIP_API_TOKEN=${config.sops.secrets.${token}.path}
      '';
      owner = "nginx";
      group = "nginx";
    };

    security.acme = {
      acceptTerms = true;
      defaults = {
        dnsProvider = "spaceship";
        email = "waynevanson@gmail.com";
        group = "nginx";
        environmentFile = config.sops.templates.${secretPath}.path;
      };

      certs.${domain}.extraDomainNames = ["*.${domain}"];
    };
  };
}
