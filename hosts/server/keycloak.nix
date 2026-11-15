# Keycloak (keycloak.waynevanson.com)
#
# Identity and access management (OIDC/OAuth2/SAML) for the services on this
# host. Keycloak listens on loopback only; nginx terminates TLS with the shared
# `waynevanson.com` certificate and forwards X-Forwarded-* on top.
#
# The store/cache lives in /var/lib/keycloak (OS SSD), users/clients live in
# PostgreSQL. Back that database up before a reinstall: losing it loses every
# configured realm, client and user.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  # `security.pki.caBundle` is NSS' ca-bundle.crt, which mixes plain
  # "BEGIN CERTIFICATE" blocks with "BEGIN TRUSTED CERTIFICATE" ones. The
  # latter carry OpenSSL trust attributes after the DER certificate, and the
  # JDBC driver reads `sslrootcert` with
  # `CertificateFactory.generateCertificates`, which aborts on them with
  # `java.io.IOException: extra data at the end`. Round-tripping the bundle
  # through PKCS#7 drops the attributes and leaves plain PEM the JVM accepts.
  dbCaBundle = pkgs.runCommand "keycloak-db-ca-bundle.pem" {
    nativeBuildInputs = [ pkgs.openssl ];
  } ''
    openssl crl2pkcs7 -nocrl -certfile ${config.security.pki.caBundle} \
      | openssl pkcs7 -print_certs -out $out
  '';
in
{
  services.keycloak = {
    enable = true;

    # PostgreSQL is already running for JuiceFS. The NixOS module provisions the
    # `keycloak` role and database itself (keycloakPostgreSQLInit) and reads the
    # role password from this file, so no manual `ensureDatabases` entry.
    #
    # `host` must stay `localhost`: the module only creates the role/database
    # when it is the default (or when `createLocally` is set explicitly). Both
    # loopback addresses are allowed to log in over TLS in `postgresql.nix`,
    # because `localhost` may resolve to `::1` for the JVM.
    database = {
      type = "postgresql";
      host = "localhost";
      createLocally = true;
      # `postgresql.nix` only accepts TLS connections (`hostssl` in
      # authentication). The loopback certificate is issued by Let's Encrypt, so
      # a system CA bundle validates it; hostname verification is off
      # (`sslmode=verify-ca`), which is what lets `localhost` use a certificate
      # for postgres.waynevanson.com.
      useSSL = true;
      caCert = dbCaBundle;
      passwordFile = config.sops.secrets.keycloak-db-password.path;
    };

    settings = {
      hostname = "keycloak.waynevanson.com";

      # nginx is the only client and speaks plain HTTP from loopback, so keep
      # Keycloak off the network and tell it to trust nginx's X-Forwarded-*
      # headers when it builds public URLs.
      http-enabled = true;
      http-host = "127.0.0.1";
      http-port = 8080;
      proxy-headers = "xforwarded";

      # Only read on the very first start, while the master realm has no users.
      # `initialAdminPassword` would put the password in the world-readable Nix
      # store, so it comes from sops like the database password.
      bootstrap-admin-username = "admin";
      bootstrap-admin-password = {
        _secret = config.sops.secrets.keycloak-admin-password.path;
      };
    };
  };

  # Both passwords are sops secrets. The init unit reads the database password
  # before Keycloak can start, Keycloak itself reads the bootstrap password.
  systemd.services.keycloakPostgreSQLInit = {
    wants = [ "sops-install-secrets.service" ];
    after = [ "sops-install-secrets.service" ];
  };

  systemd.services.keycloak = {
    wants = [ "sops-install-secrets.service" ];
    after = [ "sops-install-secrets.service" ];
  };

  # The name must be on the shared certificate, so its DNS record has to exist
  # or renewal fails for every site on the certificate (blog, S3, WordPress).
  security.acme.certs."waynevanson.com".extraDomainNames = [ "keycloak.waynevanson.com" ];

  services.nginx.virtualHosts."keycloak.waynevanson.com" = {
    useACMEHost = "waynevanson.com";
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:8080";
      proxyWebsockets = true;
      extraConfig = ''
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-Port $server_port;

        # Keycloak sessions add up to several cookies on the admin console,
        # which overflow nginx's default 8k response header buffer and show up
        # as unexplained 502s.
        proxy_buffer_size 16k;
        proxy_buffers 8 16k;

        # Theme jars and realm files are uploaded through the admin console.
        client_max_body_size 100m;
      '';
    };
  };
}
