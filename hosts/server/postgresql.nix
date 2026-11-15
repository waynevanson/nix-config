# PostgreSQL backing the JuiceFS metadata engine (see hosts/desktop/juicefs.nix).
#
# Postgres listens on loopback only. The public entry point is TCP :2345,
# forwarded by the router to this host. nginx's stream proxy pipes those bytes
# to PgBouncer on 127.0.0.1:6432, which terminates the client TLS connection
# with the same `postgres.waynevanson.com` certificate and then opens its own
# TLS connection to Postgres. JuiceFS clients connect with
# `sslmode=verify-full`, so they are unchanged by the extra hop.
#
# PgBouncer only pools connections, never query results: the metadata engine is
# the source of truth for the filesystem, so caching reads would hand JuiceFS
# stale inodes. Session pooling is used because JuiceFS' pgx driver keeps
# prepared statements per session.
#
# There is deliberately no fail2ban jail: nginx's stream proxy makes every
# connection appear to come from 127.0.0.1, so failed-auth log lines cannot be
# attributed to a client. Brute-force resistance is SCRAM + a random role
# password, with neither Postgres nor PgBouncer bound to a public interface.
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
      # never over TCP - including through the nginx tunnel. Both loopback
      # addresses are listed because Keycloak's JDBC driver may resolve
      # `localhost` to either one.
      hostssl all postgres 127.0.0.1/32 reject
      hostssl all postgres ::1/128      reject
      hostssl all all      127.0.0.1/32 scram-sha-256
      hostssl all all      ::1/128      scram-sha-256
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

  # PgBouncer between nginx and Postgres. It terminates client TLS itself and
  # keeps a small pool of TLS connections to the loopback Postgres open, so a
  # JuiceFS remount/reconnect does not pay for a fresh SCRAM + TLS handshake on
  # every new connection.
  #
  # The auth file carries the role password in plain text: PgBouncer needs it to
  # verify the client's SCRAM exchange *and* to complete the SCRAM exchange with
  # Postgres. It is rendered from sops into a pgbouncer-owned, 0400 file, and
  # clients are only allowed to connect over TLS (`client_tls_sslmode`).
  sops.templates."pgbouncer-userlist.txt" = {
    content = ''"juicefs" "${config.sops.placeholder.postgres-juicefs-password}"'';
    owner = "pgbouncer";
    mode = "0400";
    restartUnits = [ "pgbouncer.service" ];
  };

  # PgBouncer reads the ACME key directly. The certificate is issued with
  # `group = "postgres"` and the key is group-readable, so group membership is
  # all it needs; the key is re-read on SIGHUP (see the acme unit below).
  users.users.pgbouncer.extraGroups = [ "postgres" ];

  services.pgbouncer = {
    enable = true;
    settings = {
      pgbouncer = {
        listen_addr = "127.0.0.1";
        listen_port = 6432;

        # Transaction pooling would break JuiceFS' cached prepared statements
        # (or need max_prepared_statements), and the metadata traffic is
        # long-lived anyway. The win is connection reuse across reconnects plus
        # a hard cap on backend connections.
        pool_mode = "session";
        max_client_conn = 50;
        default_pool_size = 20;

        auth_type = "scram-sha-256";
        auth_file = config.sops.templates."pgbouncer-userlist.txt".path;

        # Clients must use TLS; JuiceFS already asks for `sslmode=verify-full`.
        client_tls_sslmode = "require";
        client_tls_key_file = "/var/lib/acme/postgres.waynevanson.com/key.pem";
        client_tls_cert_file = "/var/lib/acme/postgres.waynevanson.com/fullchain.pem";

        # PgBouncer's TLS library (libtls) loads a CA file for both contexts on
        # startup even though validation is off; its compiled-in default path
        # does not exist on NixOS, so point both at the system bundle.
        client_tls_ca_file = "${config.security.pki.caBundle}";
        server_tls_ca_file = "${config.security.pki.caBundle}";

        # The backend hop is loopback-only and Postgres' `hostssl` rule requires
        # TLS, so encrypt it but do not bother validating the certificate.
        server_tls_sslmode = "require";
      };
      databases.juicefs = "host=127.0.0.1 port=5432 dbname=juicefs";
    };
  };

  # The auth file is a sops template and the TLS files come from ACME; without
  # them PgBouncer would exit on start.
  systemd.services.pgbouncer = {
    wants = [ "acme-postgres.waynevanson.com.service" ];
    after = [
      "acme-postgres.waynevanson.com.service"
      "sops-install-secrets.service"
    ];
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
    # Postgres gets a reload after the copy above (it re-reads ssl_cert_file and
    # ssl_key_file), PgBouncer reads the ACME files in place on SIGHUP.
    reloadServices = [
      "postgresql.service"
      "pgbouncer.service"
    ];
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

  # Public :2345 -> loopback PgBouncer. A dedicated port needs no SNI or
  # protocol demux; nginx only pipes bytes, and PgBouncer still does TLS.
  services.nginx.streamConfig = ''
    server {
      listen 2345;
      listen [::]:2345;
      proxy_pass 127.0.0.1:6432;
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
    databases = [
      "juicefs"
      "keycloak"
    ];
    location = "/srv/data/backups/postgresql";
    compression = "zstd";
  };
}
