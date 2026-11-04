# User-scoped mount of the Garage `files` bucket, built on Home Manager's
# `programs.rclone` module (modules/programs/rclone.nix).
#
# That module owns the plumbing this used to hand-roll:
#   * sops secrets are injected into ~/.config/rclone/rclone.conf (mode 0600) by
#     `rclone-config.service`, which it automatically orders after
#     `sops-nix.service` because we declare `programs.rclone.remotes.<x>.secrets`,
#   * each `mounts.<path>` entry becomes a systemd user unit running
#     `rclone mount garage:<path> <mountPoint>`, wanted by default.target
#     (`autoMount = true`), i.e. mounted at login and torn down with the session.
#
# NOTE on "automount": on-access mounting (the `x-systemd.automount` recipe from
# https://wiki.nixos.org/wiki/Rclone) needs to mount autofs(5), which requires
# CAP_SYS_ADMIN. A systemd *user* manager can't do that, and Home Manager has no
# root module, so user-level rclone can only be mounted eagerly at login like
# this. rclone itself only talks to S3 on first access, so it is lazy in
# practice. If you ever want true on-access + idle unmount, the equivalent
# root-level version lives in the NixOS config, e.g.:
#
#   fileSystems."/mnt/files" = {
#     device = "garage:files";
#     fsType = "rclone";
#     options = [ "nofail" "_netdev" "args2env" "x-systemd.automount"
#                 "x-systemd.idle-timeout=600" "uid=1000" "gid=100"
#                 "config=/home/waynevanson/.config/rclone/rclone.conf" ];
#   };
{
  config,
  lib,
  ...
}:
let
  remote = "garage";
  bucket = "files";
  region = "garage";
  endpoint = "https://s3.waynevanson.com";
in
{
  # Same keys the server itself uses (see modules/sops.nix), read from
  # .sops.secrets.yaml's `garage` section.
  sops.secrets.garage-access-key.key = "garage/access-key";
  sops.secrets.garage-secret-key.key = "garage/secret-key";

  programs.rclone = {
    enable = true;

    remotes.${remote} = {
      config = {
        type = "s3";
        provider = "Other";
        inherit endpoint region;
      };

      # Paths to the sops-rendered files; injected into rclone.conf at
      # activation time so the credentials never hit the nix store.
      secrets = {
        access_key_id = config.sops.secrets.garage-access-key.path;
        secret_access_key = config.sops.secrets.garage-secret-key.path;
      };

      mounts.${bucket} = {
        enable = true;
        autoMount = true;
        mountPoint = "${config.home.homeDirectory}/mnt/files";
        logLevel = "INFO";
        options = {
          vfs-cache-mode = "writes";
          vfs-cache-max-age = "24h";
          vfs-cache-max-size = "10G";
          vfs-cache-poll-interval = "5m";
          vfs-write-back = "5s";
          dir-cache-time = "1m";
          attr-timeout = "1m";
          umask = "0022";
        };
      };
    };
  };
}
