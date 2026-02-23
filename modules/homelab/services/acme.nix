{
  config,
  lib,
  ...
}: let
  config' = config.homelab.services.acme;
  # todo: docs looked incorrect and this looks correct
  webroot = "/var/lib/acme/.challenges";
in {
  options.homelab.services.acme.enable = lib.mkEnableOption {};

  config = lib.mkIf config'.enable {
    # /var/lib/acme/.challenges must be writable by the ACME user
    # and readable by the Nginx user. The easiest way to achieve
    # this is to add the Nginx user to the ACME group.
    users.users.nginx.extraGroups = ["acme"];

    # Allow Nginx to listen to
    services.nginx.virtualHosts = {
      "waynevanson.com" = {
        locations = {
          "/.well-known/health-check".return = "204";

          # Place challenged in a common directory
          "/.well-known/acme-challenge".root = webroot;

          # Redirect everyone else to HTTPS
          # "/".return = "301 https://$host$request_uri";
        };
      };

      "192.168.1.103" = {
        locations = {
          "/.well-known/health-check".return = "204";
        };
      };
    };

    security.acme = {
      acceptTerms = true;
      defaults = {
        email = "waynevanson@gmail.com";
        # server = "https://acme-staging-v02.api.letsencrypt.org/directory";
        group = "nginx";
        inherit webroot;
      };

      certs."waynevanson.com" = {
        # todo: add this as module options
        # ["ai.waynevanson.com" "photos.waynevanson.com" "git.waynevanson.com"]
        # extraDomainNames = [];
      };
    };
  };
}
