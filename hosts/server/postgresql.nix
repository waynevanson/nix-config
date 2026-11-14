# PostgreSQL backing the JuiceFS metadata engine (see hosts/desktop/juicefs.nix).
#
# Postgres listens on loopback only. The public entry point is TCP :2345,
# forwarded by the router to this host. nginx's stream proxy pipes those bytes
# to 127.0.0.1:5432; Postgres terminates TLS itself with its own certificate, so
# JuiceFS clients connect with `sslmode=verify-full`.
#
# There is deliberately no fail2ban jail for Postgres: nginx makes every
# connection appear to come from 127.0.0.1, so failed-auth log lines cannot be
# attributed to a client. Brute-force resistance is SCRAM + a random role
# password, with Postgres itself never bound to a public interface.
{
  config,
  lib,
  pkgs,
  ...
}:
{
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_17;
    # `enableTCPIP` stays false (default), so listen_addresses = "localhost".

    settings = {
      max_connections = 100;
      ssl = "on";
      # Postgres refuses to use a key that is not owned by the database user or
      # root (ACME always chowns certs to acme:<group>), so the pre-start hook
      # below copies them into a postgres-owned directory first.
      ssl_cert_file = "/var/lib/postgresql/ssl/fullchain.pem";
      ssl_key_file = "/var/lib/postgresql/ssl/key.pem";
      ssl_min_protocol_version = "TLSv1.2";
      password_encryption = "scram-sha-256";
    };

    authentication = lib.mkForce ''
      local   all all            peer
      # The superuser is only reachable through the unix socket (peer auth),
      # never over TCP - including through the nginx tunnel.
      hostssl all postgres 127.0.0.1/32 reject
      hostssl all all      127.0.0.1/32 scram-sha-256
    '';

    ensureDatabases = [ "juicefs" ];
    ensureUsers = [
      { name = "juicefs"; ensureDBOwnership = true; }
    ];
  };

  # Postgres refuses to use a key that is not owned by the database user or
  # root. ACME always chowns certs to `acme:<group>`, so the pre-start hook
  # below copies them into a postgres-owned directory first. tmpfiles creates
  # that directory before acme/postgres start (and it is the path acme's
  # order-renew unit must be allowed to write to).
  systemd.tmpfiles.rules = [
    "d /var/lib/postgresql 0750 postgres postgres - -"
    "d /var/lib/postgresql/ssl 0700 postgres postgres - -"
  ];

  # ACME's order-renew service runs under ProtectSystem=strict; allow it to
  # write the copy that `postRun` installs. The parent always exists, whereas a
  # ReadWritePaths= entry for a not-yet-created directory makes the unit fail.
  systemd.services."acme-order-renew-postgres.waynevanson.com".serviceConfig.ReadWritePaths =
    lib.mkAfter [ "/var/lib/postgresql" ];

  # ensureUsers creates LOGIN roles but no passwords; apply them from sops on
  # every boot. `postgresql-setup` is what creates the roles/databases.
  sops.templates."postgres-roles.sql".content = ''
    ALTER ROLE juicefs PASSWORD '${config.sops.placeholder.postgres-juicefs-password}';
  '';
  sops.templates."postgres-roles.sql".owner = "postgres";
  sops.templates."postgres-roles.sql".mode = "0400";
  sops.templates."postgres-roles.sql".restartUnits = [ "postgresql-roles.service" ];

  systemd.services.postgresql-roles = {
    description = "Apply PostgreSQL role passwords from sops";
    after = [ "postgresql-setup.service" "sops-install-secrets.service" ];
    requires = [ "postgresql-setup.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = "postgres";
      ExecStart = "${config.services.postgresql.package}/bin/psql -f ${
        config.sops.templates."postgres-roles.sql".path
      }";
    };
  };

  # With ssl=on, a missing certificate prevents startup. On a cold boot the acme
  # unit must have written it first; `wants` keeps a failed acme from blocking
  # the rest of the boot (the postgres unit retries once the cert appears).
  systemd.services.postgresql = {
    wants = [ "acme-postgres.waynevanson.com.service" ];
    after = [ "acme-postgres.waynevanson.com.service" ];
  };

  # Dedicated certificate: the web/S3 private key is never exposed to the
  # `postgres` user. DNS-01, so port 80 stays available for the HTTP redirect.
  security.acme.certs."postgres.waynevanson.com" = {
    group = "postgres";
    dnsProvider = "spaceship";
    credentialFiles = {
      "SPACESHIP_API_KEY_FILE" = config.sops.secrets.spaceship-client-id.path;
      "SPACESHIP_API_SECRET_FILE" = config.sops.secrets.spaceship-client-secret.path;
    };
    # Copy must happen before the reload below. `postRun` only runs when lego
    # actually renewed the certificate; the boot path is handled by
    # `postgresql`'s pre-start hook further down.
    postRun = ''
      ${pkgs.coreutils}/bin/install -d -o postgres -g postgres -m 0700 /var/lib/postgresql/ssl
      ${pkgs.coreutils}/bin/install -o postgres -g postgres -m 0600 \
        /var/lib/acme/postgres.waynevanson.com/key.pem /var/lib/postgresql/ssl/key.pem
      ${pkgs.coreutils}/bin/install -o postgres -g postgres -m 0644 \
        /var/lib/acme/postgres.waynevanson.com/fullchain.pem /var/lib/postgresql/ssl/fullchain.pem
    '';
    reloadServices = [ "postgresql.service" ];
  };

  # Runs as the postgres user. The ACME key/cert are group-readable (the cert is
  # issued with `group = "postgres"`), and the copy is owned by postgres with
  # 0600, which is what Postgres' key permission check requires. Kept in
  # `preStart` (not `postRun`) so a reboot without a renewal still refreshes it.
  systemd.services.postgresql.preStart = lib.mkAfter ''
    ${pkgs.coreutils}/bin/install -d -m 0700 /var/lib/postgresql/ssl
    ${pkgs.coreutils}/bin/install -m 0600 /var/lib/acme/postgres.waynevanson.com/key.pem \
      /var/lib/postgresql/ssl/key.pem
    ${pkgs.coreutils}/bin/install -m 0644 /var/lib/acme/postgres.waynevanson.com/fullchain.pem \
      /var/lib/postgresql/ssl/fullchain.pem
  '';

  # Public :2345 -> loopback Postgres. A dedicated port needs no SNI or protocol
  # demux; nginx only pipes bytes, and Postgres still does end-to-end TLS.
  services.nginx.streamConfig = ''
    server {
      listen 2345;
      listen [::]:2345;
      proxy_pass 127.0.0.1:5432;
      proxy_connect_timeout 5s;
      proxy_timeout 1h;   # JuiceFS keeps SQL connections open
    }
  '';

  # NOTE: nixpkgs' nginx is not built with --with-stream_limit_conn_module, so
  # `limit_conn` cannot be used in the stream block without overriding the
  # package. The dedicated port plus SCRAM passwords are the only controls.

  networking.firewall.allowedTCPPorts = [ 2345 ];

  services.postgresqlBackup = {
    enable = true;
    databases = [ "juicefs" ];
    location = "/srv/data/backups/postgresql";
    compression = "zstd";
  };
}
