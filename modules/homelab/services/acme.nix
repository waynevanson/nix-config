# `acme`
{
  config,
  lib,
  ...
}: let
  config' = config.homelab.services.acme;
  certs = "/var/lib/acme/${config'.domain}";
  dotenv = "spaceship.env";
  token = "spaceship/token";
in {
  options.homelab.services.acme = {
    enable = lib.mkEnableOption {};

    domain = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default = "waynevanson.com";
    };

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

    services.nginx.virtualHosts."${config'.domain}" = {
      # todo: Apply certs to all virtual hosts
      addSSL = true;
      sslCertificateKey = config'.certificate;
      sslCertificate = config'.key;
    };

    security.acme = {
      acceptTerms = true;
      defaults = {
        dnsProvider = "spaceship";
        group = "nginx";
        email = "waynevanson@gmail.com";
        environmentFile = config.sops.templates.${dotenv}.path;
      };

      certs.${config'.domain}.extraDomainNames = ["*.${config'.domain}"];
    };

    # DNS validation
    sops = {
      secrets.${token} = {
        owner = "nginx";
        group = "nginx";
      };

      templates.${dotenv} = {
        content = ''
          SPACESHIP_API_KEY=ka3Ec2FcvBmwagXS27QA
          SPACESHIP_API_TOKEN=${config.sops.placeholder.${token}}
        '';
        owner = "nginx";
        group = "nginx";
      };
    };

    # /var/lib/acme/.challenges must be writable by the ACME user
    # and readable by the Nginx user. The easiest way to achieve
    # this is to add the Nginx user to the ACME group.
    users.users.nginx.extraGroups = ["acme"];
  };
}
