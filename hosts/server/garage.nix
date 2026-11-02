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
