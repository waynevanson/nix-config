{
  config,
  lib,
  ...
}: let
  cfg = config.homelab.nginx;
in {
  options.homelab.nginx = {
    enable = true;
  };

  config = lib.mkIf cfg.enable {
    services.nginx = {
      enable = true;

      # Use recommended settings
      recommendedGzipSettings = true;
      recommendedOptimisation = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;

      appendHttpConfig = ''
        # Add HSTS header with preloading to HTTPS requests.
        # Adding this header to HTTP requests is discouraged
        map $scheme $hsts_header {
            https   "max-age=31536000; includeSubdomains; preload";
        }
        add_header Strict-Transport-Security $hsts_header;

        # Enable CSP for your services.
        #add_header Content-Security-Policy "script-src 'self'; object-src 'none'; base-uri 'none';" always;

        # Minimize information leaked to other domains
        add_header 'Referrer-Policy' 'origin-when-cross-origin';

        # Disable embedding as a frame
        add_header X-Frame-Options DENY;

        # Prevent injection of code in other mime types (XSS Attacks)
        add_header X-Content-Type-Options nosniff;

        # This might create errors
        proxy_cookie_path / "/; secure; HttpOnly; SameSite=strict";
      '';

      virtualHosts = {
        # I want all these paths for certs,
        # then configure each app/service separately.
        "*.waynevanson.com" = {
          enableACME = true;
          forceSSL = true;

          locations."/" = {
            enableACME = true;
            addSSL = true;

            # Set true when app requires websockets
            proxyWebsockets = false;

            # Think this is who i pass the traffic to?
            proxyPass = "http://127.0.0.1:12345";
          };
        };
      };
    };

    security.acme = {
      acceptTerms = true;
      defaults.email = "waynevanson@gmail.com";
    };

    firewall.allowedTCPPorts = [80 443];
  };
}
