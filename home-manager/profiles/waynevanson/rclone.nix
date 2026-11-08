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
  # Bucket-scoped key, NOT the server's default (cluster-wide) key.
  #
  # Create it on the server once it is up:
  #   garage key create desktop-files
  #   garage bucket allow --read --write files --key desktop-files
  #   garage key info --show-secret desktop-files
  # then add the two values to sops under `garage/desktop-access-key` and
  # `garage/desktop-secret-key`. Until they exist, sops-install-secrets fails at
  # activation and the mount stays down - deliberately, so this mount can never
  # fall back to the server's cluster-wide key.
  sops.secrets.garage-desktop-access-key.key = "garage/desktop-access-key";
  sops.secrets.garage-desktop-secret-key.key = "garage/desktop-secret-key";

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
        access_key_id = config.sops.secrets.garage-desktop-access-key.path;
        secret_access_key = config.sops.secrets.garage-desktop-secret-key.path;
      };

      mounts.${bucket} = {
        enable = true;
        autoMount = true;
        mountPoint = "${config.home.homeDirectory}/mnt/files";
        logLevel = "INFO";
        options = {
          vfs-cache-mode = "minimal";
          vfs-cache-min-free-space = "20G";
          vfs-cache-poll-interval = "1m";
          vfs-cache-max-age = "24h";
          vfs-read-chunk-size = "64M";
          vfs-read-chunk-streams = 4;
          dir-cache-time = "10s";
          attr-timeout = "1m";
          umask = "0022";
        };
      };
    };
  };
}
