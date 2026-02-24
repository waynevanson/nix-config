# todo: DNS level? sops-nix to hold secrets from spaceship
# todo: a service
{
  config,
  lib,
  ...
}: let
  config' = config.homelab.services.acme;
  challenges = "/var/lib/acme/.challenges";
  certs = "/var/lib/acme/waynevanson.com";
  # takes hosts
  # createApplication = lib.mapAttrs (hostname: value: {});
in {
  options.homelab.services.acme = {
    enable = lib.mkEnableOption {};
    # Record<hostname, {acme,}>
    # hosts = lib.mkAttrsOption {};
  };

  config = lib.mkIf config'.enable {
    # /var/lib/acme/.challenges must be writable by the ACME user
    # and readable by the Nginx user. The easiest way to achieve
    # this is to add the Nginx user to the ACME group.
    users.users.nginx.extraGroups = ["acme"];

    # Allow Nginx to listen to
    services.nginx.virtualHosts = {
      "waynevanson.com" = {
        addSSL = true;
        sslCertificateKey = "${certs}/key.pem";
        sslCertificate = "${certs}/cert.pem";
        locations = {
          # Place challenged in a common directory
          "/.well-known/acme-challenge".root = challenges;
        };
      };
    };

    security.acme = {
      acceptTerms = true;
      defaults = {
        email = "waynevanson@gmail.com";
        group = "nginx";
        webroot = challenges;
      };

      certs."waynevanson.com" = {
        # todo: check if this works.
        extraDomainNames = ["git.waynevanson.com"];
      };
    };
  };
}
