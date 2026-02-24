# great this works.
{
  lib,
  config,
  ...
}: let
  cfg = config.services.forgejo;
  srv = cfg.settings.server;
  certs = "/var/lib/acme/waynevanson.com";
in {
  options.homelab.services.git.enable = lib.mkEnableOption {};

  config.services = lib.mkIf config.homelab.services.git.enable {
    nginx = {
      virtualHosts.${cfg.settings.server.DOMAIN} = {
        forceSSL = true;
        sslCertificateKey = "${certs}/key.pem";
        sslCertificate = "${certs}/cert.pem";
        extraConfig = ''
          client_max_body_size 512M;
        '';
        locations."/".proxyPass = "http://localhost:${toString srv.HTTP_PORT}";
      };
    };

    forgejo = {
      enable = true;
      database.type = "postgres";
      # Enable support for Git Large File Storage
      lfs.enable = true;
      settings = {
        server = {
          DOMAIN = "git.waynevanson.com";
          ROOT_URL = "https://${srv.DOMAIN}/";
          HTTP_PORT = 3000;
        };
      };
    };
  };
}
