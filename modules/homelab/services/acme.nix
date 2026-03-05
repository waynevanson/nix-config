# `acme`
{
  config,
  lib,
  ...
}: let
  config' = config.homelab.services.acme;
  certs = "/var/lib/acme/waynevanson.com";
  dotenv = "spaceship.env";
  path = "spaceship/token";
  token = "spaceship-token";
  owner = config.users.users.acme.name;
  group = config.users.users.acme.group;
in {
  options.homelab.services.acme = {
    enable = lib.mkEnableOption {};

    certificate = lib.mkOption {
      type = lib.types.str;
      default = "${certs}/cert.pem";
      readOnly = true;
    };

    key = lib.mkOption {
      type = lib.types.str;
      default = "${certs}/key.pem";
      readOnly = true;
    };
  };

  config = lib.mkIf config'.enable {
    networking.firewall.allowedTCPPorts = [80 443];

    services.nginx.virtualHosts."waynevanson.com" = {
      addSSL = true;
      enableACME = true;
      sslCertificate = config'.certificate;
      sslCertificateKey = config'.key;
    };

    security.acme = {
      acceptTerms = true;
      defaults = {
        dnsProvider = "spaceship";
        group = "nginx";
        email = "waynevanson@gmail.com";
        environmentFile = config.sops.templates.${dotenv}.path;
      };

      certs."waynevanson.com" = {
        domain = "waynevanson.com";
        extraDomainNames = ["*.waynevanson.com"];
        dnsPropagationCheck = true;
      };
    };

    # DNS validation
    sops = {
      secrets.${token} = {
        key = path;
        inherit owner group;
      };

      templates.${dotenv} = {
        content = ''
          SPACESHIP_API_KEY=ka3Ec2FcvBmwagXS27QA
          SPACESHIP_API_SECRET=${config.sops.placeholder.${token}}
        '';
        inherit owner group;
      };
    };

    # /var/lib/acme/.challenges must be writable by the ACME user
    # and readable by the Nginx user. The easiest way to achieve
    # this is to add the Nginx user to the ACME group.
    users.users.nginx.extraGroups = ["acme"];
  };
}
