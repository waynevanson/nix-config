{
  config,
  lib,
  ...
}: let
  config' = config.homelab.services.ssl;
  certs = "/var/lib/acme/${config'.domain}";
  secret = ".env.spaceship";
  token = "spaceship/token";
in {
  options.homelab.services.ssl = {
    enable = lib.mkEnableOption {};

    domain = lib.mkOption {
      type = lib.types.str;
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
    # /var/lib/acme/.challenges must be writable by the ACME user
    # and readable by the Nginx user. The easiest way to achieve
    # this is to add the Nginx user to the ACME group.
    users.users.nginx.extraGroups = ["acme"];
    users.users.acme.extraGroups = ["nginx"];

    # Allow Nginx to listen to
    homelab.services.reverse-proxy.virtualHosts."${config'.domain}" = {
      # todo: Apply certs to all virtual hosts
      addSSL = true;
      sslCertificateKey = config'.certificate;
      sslCertificate = config'.key;
    };

    sops = {
      secrets.${token} = {
        owner = "nginx";
        group = "nginx";
      };

      templates.${secret} = {
        content = ''
          SPACESHIP_API_KEY=ka3Ec2FcvBmwagXS27QA
          SPACESHIP_API_TOKEN=${config.sops.placeholder.${token}}
        '';
        owner = "nginx";
        group = "nginx";
      };
    };

    security.acme = {
      acceptTerms = true;
      defaults = {
        dnsProvider = "spaceship";
        group = "nginx";
        email = "waynevanson@gmail.com";
        environmentFile = config.sops.templates.${secret}.path;
      };

      certs.${config'.domain}.extraDomainNames = ["*.${config'.domain}"];
    };
  };
}
