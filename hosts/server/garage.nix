{
  config,
  lib,
  pkgs,
  ...
}:
let
  group = "garage";
  port = {
    s3 = "3900";
    rpc = "3901";
  };
  defaultBucket = "files";
in
{
  security.acme.certs."waynevanson.com".extraDomainNames = [
    "s3.waynevanson.com"
    "*.s3.waynevanson.com"
  ];

  sops.templates.garage-environment-file = {
    content = ''
      GARAGE_RPC_SECRET=${config.sops.placeholder.garage-rpc-secret}
      GARAGE_DEFAULT_ACCESS_KEY=${config.sops.placeholder.garage-access-key}
      GARAGE_DEFAULT_SECRET_KEY=${config.sops.placeholder.garage-secret-key}
      GARAGE_DEFAULT_BUCKET=${defaultBucket}
    '';
    owner = group;
    restartUnits = [ "garage.service" ];
  };

  users = {
    groups.${group} = { };
    users.${group} = {
      isSystemUser = true;
      group = group;
    };
  };

  services = {
    garage = {
      enable = true;
      package = pkgs.garage_2;
      environmentFile = config.sops.templates.garage-environment-file.path;
      settings = {
        replication_factor = 1;
        consistency_mode = "consistent";
        metadata_dir = "/srv/data/garage/meta";
        data_dir = "/srv/data/garage";
        rpc_bind_addr = "[::]:${port.rpc}";
        s3_api = {
          api_bind_addr = "[::]:${port.s3}";
          s3_region = "garage";
        };
      };
    };

    nginx.virtualHosts."s3.waynevanson.com" = {
      useACMEHost = "waynevanson.com";
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://localhost:${port.s3}";
        extraConfig = ''
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_max_temp_file_size 0;
          client_max_body_size 0;
        '';
      };
    };
  };

  # Key material for the desktop's bucket-scoped S3 key lives in sops, so it can
  # be provisioned here in advance (see garage-client-key below) instead of being
  # created by hand once the host is up. The server's own default key is not used
  # by clients.
  sops.secrets.garage-desktop-access-key.key = "garage/desktop-access-key";
  sops.secrets.garage-desktop-secret-key.key = "garage/desktop-secret-key";

  systemd = {
    tmpfiles.rules = [
      "d /srv/data/garage 0750 ${group} ${group} -"
      "d /srv/data/garage/meta 0750 ${group} ${group} -"
    ];

    # Import the desktop key (idempotent) and grant it read/write on the default
    # bucket only. Garage 2.x's CLI talks to the local node over RPC, so this
    # needs no Admin API or admin token - just the RPC secret the daemon already
    # gets from sops.
    services.garage-client-key = {
      description = "Import the desktop's bucket-scoped Garage key";
      wantedBy = [ "multi-user.target" ];
      wants = [ "garage.service" ];
      after = [ "garage.service" ];
      path = [
        config.services.garage.package
        pkgs.coreutils
      ];
      environment = {
        GARAGE_DESKTOP_KEY_NAME = "desktop-files";
      };
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        EnvironmentFile = config.sops.templates.garage-environment-file.path;
        ExecStart = pkgs.writeShellScript "garage-client-key" ''
          set -eu

          # Wait for the daemon, then for the default bucket to exist.
          for _ in $(seq 60); do
            garage bucket info ${defaultBucket} >/dev/null 2>&1 && break
            sleep 2
          done

          if ! garage bucket info ${defaultBucket} >/dev/null 2>&1; then
            echo "bucket ${defaultBucket} did not appear, giving up" >&2
            exit 1
          fi

          if ! garage key info "$GARAGE_DESKTOP_KEY_NAME" >/dev/null 2>&1; then
            garage key import \
              "$(cat ${config.sops.secrets.garage-desktop-access-key.path})" \
              "$(cat ${config.sops.secrets.garage-desktop-secret-key.path})" \
              --yes -n "$GARAGE_DESKTOP_KEY_NAME"
          fi

          garage bucket allow --read --write ${defaultBucket} \
            --key "$GARAGE_DESKTOP_KEY_NAME"
        '';
      };
    };

    services.garage = {
      unitConfig.RequiresMountsFor = [ "/srv/data" ];
      serviceConfig = {
        ExecStart = lib.mkForce "${config.services.garage.package}/bin/garage server --single-node --default-bucket";
        DynamicUser = lib.mkForce false;
        User = group;
        Group = group;
      };
    };
  };
}
