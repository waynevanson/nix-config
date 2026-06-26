# Plan: mount Garage/S3 bucket on first access at `~/cloud`

## Goal
Lazily mount a bucket from the Garage S3 server onto the desktop so that the
first `ls ~/cloud` triggers the mount, and it unmounts after an idle timeout.

## Why not the Home Manager module?
`programs.rclone` creates user services that start at login (`autoMount`).
It does **not** provide systemd `.automount` idle-unmount behaviour, so we will
use a small NixOS system module instead.

## Decisions
1. **Bucket**: create a dedicated bucket (e.g. `files`) on the server. Do not
   mount `attic`; Atticd owns it.
2. **Scope**: system-level NixOS module that creates `systemd.mounts` +
   `systemd.automounts`. Root runs the FUSE daemon, but files are presented as
   owned by `waynevanson:users`.
3. **Mount point**: `/home/waynevanson/cloud`.
4. **Credentials**: reuse the existing `garage/access-key` and
   `garage/secret-key` entries from `.sops.secrets.yaml`, rendered into an
   rclone config file by a sops template.

## Files to change
- `modules/custom/services/rclone-mount.nix` (new)
- `modules/custom/services/default.nix` (add import)
- `hosts/desktop/default.nix` (enable/configure the module)

## Implementation

### 1. Create `modules/custom/services/rclone-mount.nix`

```nix
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.custom.services.rclone-mount;
  mountUnitName = lib.systemdUtils.unitName
    "${lib.replaceStrings ["/"] ["-"] cfg.mountpoint}.mount";

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
      --uid ${toString config.users.users.${cfg.user}.uid} \
      --gid ${toString config.users.groups.${cfg.group}.gid} \
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
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "users";
    };

    umask = lib.mkOption {
      type = lib.types.str;
      default = "0022";
    };

    idleTimeout = lib.mkOption {
      type = lib.types.str;
      default = "5min";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.fuse.enable = true;

    environment.systemPackages = [ mountWrapper pkgs.rclone ];

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
        restartUnits = [ mountUnitName ];
      };
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.mountpoint} 0750 ${cfg.user} ${cfg.group} -"
    ];

    systemd.mounts = [{
      where = cfg.mountpoint;
      what = "garage:${cfg.bucket}";
      type = "rclone";
      mountConfig = {
        Options = "_netdev";
        LazyUnmount = true;
      };
    }];

    systemd.automounts = [{
      where = cfg.mountpoint;
      wantedBy = [ "multi-user.target" ];
      automountConfig = {
        TimeoutIdleSec = cfg.idleTimeout;
      };
    }];
  };
}
```

### 2. Register the module

In `modules/custom/services/default.nix` add `./rclone-mount.nix` to `imports`.

### 3. Enable it on the desktop

In `hosts/desktop/default.nix` add to `custom'`:

```nix
custom.services.rclone-mount = {
  enable = true;
  bucket = "files";
  mountpoint = "/home/waynevanson/cloud";
};
```

### 4. Create the bucket on the server

On `server`:

```bash
garage bucket create files
garage bucket allow --read --write files
```

### 5. Deploy and verify

```bash
sudo nixos-rebuild switch --flake .#nixos
systemctl status home-waynevanson-cloud.automount
ls /home/waynevanson/cloud   # triggers mount
systemctl status home-waynevanson-cloud.mount
journalctl -u home-waynevanson-cloud.mount
```

## Notes / risks
- `mount.rclone` must be on `PATH` when systemd runs `mount(8)`. Adding the
  wrapper package to `environment.systemPackages` makes it available in the
  system environment.
- `--daemon` lets the helper exit while the FUSE filesystem stays mounted.
  systemd detects the mount via `/proc/self/mountinfo`.
- `--allow-other` requires `programs.fuse.enable = true` so the non-root user
  can access a root-owned FUSE mount.
- If the bucket does not exist, the mount will fail on first access.
