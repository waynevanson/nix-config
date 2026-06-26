{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.custom.services.rclone-mount;

  escapedMountpoint = lib.removePrefix "-" (lib.replaceStrings [ "/" ] [ "-" ] cfg.mountpoint);
  mountUnit = "${escapedMountpoint}.mount";

  mountWrapper = pkgs.writeShellScriptBin "mount.rclone" ''
    # mount(8) invokes helpers as: mount.rclone [-o opts] <what> <where>
    shift $(($# - 2))
    WHAT="$1"
    WHERE="$2"

    exec ${lib.getExe pkgs.rclone} mount "$WHAT" "$WHERE" \
      --config ${config.sops.templates.rclone-garage-config.path} \
      --vfs-cache-mode minimal \
      --dir-cache-time 5m \
      --no-modtime \
      --uid $(id -u ${cfg.user}) \
      --gid $(id -g ${cfg.group}) \
      --umask ${cfg.umask} \
      --allow-other \
      --daemon \
      --log-file /var/log/rclone-garage-mount.log
  '';
in
{
  options.custom.services.rclone-mount = {
    enable = lib.mkEnableOption "rclone lazy S3 mount";

    bucket = lib.mkOption {
      type = lib.types.str;
      default = "files";
      description = "S3 bucket to mount.";
    };

    mountpoint = lib.mkOption {
      type = lib.types.str;
      default = "/home/waynevanson/cloud";
      description = "Local mount point.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "waynevanson";
      description = "Owner used for files inside the mount.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "users";
      description = "Group used for files inside the mount.";
    };

    umask = lib.mkOption {
      type = lib.types.str;
      default = "0022";
      description = "Umask used for files inside the mount.";
    };

    idleTimeout = lib.mkOption {
      type = lib.types.str;
      default = "5min";
      description = "Idle time before systemd automount unmounts.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.fuse.enable = true;

    environment.systemPackages = [
      mountWrapper
      pkgs.rclone
    ];

    sops = {
      templates.rclone-garage-config = {
        content = ''
          [garage]
          type = s3
          provider = Other
          env_auth = false
          access_key_id = ${config.sops.placeholder.garage-access-key}
          secret_access_key = ${config.sops.placeholder.garage-secret-key}
          endpoint = s3.garage.waynevanson.com
          region = garage
          force_path_style = true
        '';
        restartUnits = [ mountUnit ];
      };
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.mountpoint} 0750 ${cfg.user} ${cfg.group} -"
    ];

    systemd.mounts = [
      {
        where = cfg.mountpoint;
        what = "garage:${cfg.bucket}";
        type = "rclone";
        options = "_netdev";
        mountConfig = {
          LazyUnmount = true;
        };
      }
    ];

    systemd.automounts = [
      {
        where = cfg.mountpoint;
        wantedBy = [ "multi-user.target" ];
        automountConfig = {
          TimeoutIdleSec = cfg.idleTimeout;
        };
      }
    ];
  };
}
