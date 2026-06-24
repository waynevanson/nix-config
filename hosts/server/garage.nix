# todo: expose the other ports so it can be used by clients?
# todo: make accessible for s5cmd
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
in
{
  security.acme.certs."waynevanson.com".extraDomainNames = [
    "s3.garage.waynevanson.com"
    "*.s3.garage.waynevanson.com"
  ];

  sops.templates.garage-environment-file = {
    content = ''
      GARAGE_RPC_SECRET=${config.sops.placeholder.garage-rpc-secret}
      GARAGE_DEFAULT_ACCESS_KEY=${config.sops.placeholder.garage-access-key}
      GARAGE_DEFAULT_SECRET_KEY=${config.sops.placeholder.garage-secret-key}
      GARAGE_DEFAULT_BUCKET="attic"
    '';
    owner = group;
  };

  users.groups.${group} = { };
  users.users.${group} = {
    isSystemUser = true;
    group = group;
  };

  services.garage = {
    enable = true;
    package = config.nixpkgs.pkgs.garage_2;
    environmentFile = config.sops.templates.garage-environment-file.path;
    settings = {
      replication_factor = 1;
      consistency_mode = "consistent";
      data_dir = "/srv/tank/garage";
      rpc_bind_addr = "[::]:${port.rpc}";
      s3_api = {
        api_bind_addr = "[::]:${port.s3}";
        s3_region = "garage";
      };
    };
  };

  systemd.tmpfiles.rules = [
    "d /srv/tank/garage 0750 ${group} ${group} -"
  ];

  systemd.services.garage.serviceConfig = {
    # Override binary since we're using garage@^2
    ExecStart = lib.mkForce "${config.services.garage.package}/bin/garage server --single-node --default-bucket";

    DynamicUser = lib.mkForce false;
  };

  systemd.services.garage-create-attic-bucket = {
    description = "Create the Attic S3 bucket in Garage";
    after = [ "garage.service" ];
    requires = [ "garage.service" ];
    before = [ "atticd.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = group;
      Group = group;
      EnvironmentFile = config.sops.templates.garage-environment-file.path;
      ExecStart = pkgs.writeShellScript "garage-create-attic-bucket" ''
        set -euo pipefail
        export PATH="${lib.makeBinPath [ config.services.garage.package ]}:$PATH"
        if ! garage bucket info attic >/dev/null 2>&1; then
          garage bucket create attic
          garage bucket allow --read --write --key "$GARAGE_DEFAULT_ACCESS_KEY" attic
        fi
      '';
    };
  };

  services.nginx.virtualHosts."s3.garage.waynevanson.com" = {
    useACMEHost = "waynevanson.com";
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://localhost:${port.s3}";
      extraConfig = ''
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;

        # https://garagehq.deuxfleurs.fr/documentation/cookbook/reverse-proxy/#exposing-the-s3-endpoints
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_max_temp_file_size 0;
        client_max_body_size 0;
      '';
    };
  };
}
