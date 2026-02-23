{
  config,
  lib,
  ...
}: let
  config' = config.homelab.services.acme;
  email = "waynevanson@gmail.com";
  # todo: docs looked incorrect and this looks correct
  group = "nginx";
  webroot = "/var/lib/acme/.challenges";
in {
  options.homelab.services.acme.enable = lib.mkEnableOption {};

  config = lib.mkIf config'.enable {
    # /var/lib/acme/.challenges must be writable by the ACME user
    # and readable by the Nginx user. The easiest way to achieve
    # this is to add the Nginx user to the ACME group.
    users.users.nginx.extraGroups = [group];

    # Allow Nginx to listen to
    services.nginx.virtualHosts."acmechallenge.waynevanson.com" = {
      serverAliases = ["*.waynevanson.com"];
      locations = {
        # Place challenged in a common directory
        "/.well-known/acme-challenge".root = webroot;

        # Redirect everyone else to HTTPS
        "/".return = "301 https://$host$request_uri";
      };
    };

    security.acme = {
      acceptTerms = true;
      defaults.email = "waynevanson@gmail.com";

      certs."acmechallenge.waynevanson.com" = {
        inherit email group webroot;
        # todo: add this as module options
        # ["ai.waynevanson.com" "photos.waynevanson.com" "git.waynevanson.com"]
        extraDomainNames = [];
      };
    };

    networking.firewall.allowedTCPPorts = [80 443];
  };
}
