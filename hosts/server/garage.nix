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
  # be provisioned in advance (see custom.services.garage-client-keys below)
  # instead of being created by hand once the host is up. The server's own
  # default key is not handed out to clients.
  sops.secrets.garage-desktop-access-key.key = "garage/desktop-access-key";
  sops.secrets.garage-desktop-secret-key.key = "garage/desktop-secret-key";

  custom.services.garage-client-keys = {
    enable = true;

    keys.desktop-files = {
      accessKeyFile = config.sops.secrets.garage-desktop-access-key.path;
      secretKeyFile = config.sops.secrets.garage-desktop-secret-key.path;
    };

    # The desktop only ever talks to its own bucket, so it gets no admin/owner
    # rights and no CreateBucket right.
    buckets.${defaultBucket}.keys.desktop-files = {
      read = true;
      write = true;
    };

    # JuiceFS stores a volume as its own content-addressed object layout plus
    # metadata backups, so it gets a dedicated bucket instead of sharing `files`
    # with arbitrary objects. The desktop's mount runs `juicefs format` on first
    # boot, so the bucket must exist before the desktop switches (the key has no
    # CreateBucket right).
    buckets.juicefs = {
      create = true;
      keys.desktop-files = {
        read = true;
        write = true;
      };
    };
  };

  systemd = {
    tmpfiles.rules = [
      "d /srv/data/garage 0750 ${group} ${group} -"
      "d /srv/data/garage/meta 0750 ${group} ${group} -"
    ];

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
