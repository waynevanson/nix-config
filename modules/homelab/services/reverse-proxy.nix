# todo: the outcome, probably a module called reverse proxy
# Reverse proxy
# Open ports 80 and 443, enable acme for certs, https and hsts by default, and then route traffic to
# nixos containers powered by systemd.
#
# One challenge will be networking bridge. Privatise the network
{
  config,
  lib,
  ...
}: let
  config' = config.homelab.services.reverse-proxy;
in {
  options.homelab.services.reverse-proxy = {
    enable = lib.mkEnableOption {
      default = false;
    };

    virtualHosts = lib.mkOption {
      type = lib.types.attrsOf lib.types.attrs;
    };
  };

  config = lib.mkIf config'.enable {
    homelab.services.ssl.enable = true;

    services.nginx = {
      enable = true;

      virtualHosts = {};

      # Use recommended settings
      # recommendedGzipSettings = true;
      # recommendedOptimisation = true;
      # recommendedProxySettings = true;
      # recommendedTlsSettings = true;

      # # HSTS hardening settings
      # appendHttpConfig = ''
      #   # Add HSTS header with preloading to HTTPS requests.
      #   # Adding this header to HTTP requests is discouraged
      #   map $scheme $hsts_header {
      #       https   "max-age=31536000; includeSubdomains; preload";
      #   }
      #   add_header Strict-Transport-Security $hsts_header;

      #   # Enable CSP for your services.
      #   #add_header Content-Security-Policy "script-src 'self'; object-src 'none'; base-uri 'none';" always;

      #   # Minimize information leaked to other domains
      #   add_header 'Referrer-Policy' 'origin-when-cross-origin';

      #   # Disable embedding as a frame
      #   add_header X-Frame-Options DENY;

      #   # Prevent injection of code in other mime types (XSS Attacks)
      #   add_header X-Content-Type-Options nosniff;

      #   # This might create errors
      #   proxy_cookie_path / "/; secure; HttpOnly; SameSite=strict";
      # '';
    };
    networking.firewall.enable = true;
    networking.firewall.allowedTCPPorts = [80 443];
  };
}
