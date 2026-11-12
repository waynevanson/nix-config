# System-level JuiceFS volume backed by the Garage S3 bucket `juicefs`.
#
# This replaces the old user-scoped `programs.rclone` mount of the Garage
# `files` bucket. JuiceFS is *not* an S3 passthrough like rclone: it is a real
# POSIX filesystem with its own on-disk format (a metadata engine plus
# content-addressed chunk objects). Objects already sitting in `files` are
# therefore not visible in this mount - they stay in Garage and can be copied in
# once (see "Migrating the old bucket" at the bottom).
#
# Layout:
#   * metadata engine: SQLite at /var/lib/juicefs/files.db. One client, no extra
#     daemon to run. The metadata is backed up into the object store every hour,
#     so a lost laptop disk can be recovered with `juicefs restore`.
#   * object storage: https://s3.waynevanson.com/juicefs (Garage, provisioned
#     server-side by hosts/server/garage.nix).
#   * mount: /home/waynevanson/mnt/files, owned by waynevanson. The service runs
#     as the user instead of root, so JuiceFS creates files with the right
#     ownership and no `allow_other` / uid/gid options are needed.
{
  config,
  ...
}:
let
  user = "waynevanson";
  group = "users";
  volume = "files";
  bucket = "juicefs";
  metaDir = "/var/lib/juicefs";
  envTemplate = "juicefs-${volume}-env";
in
{
  # Pin s3.waynevanson.com to the server's public address so the mount does not
  # depend on the desktop's DNS/Tailscale setup.
  networking.extraHosts = ''
    115.186.205.123 s3.waynevanson.com
  '';

  # JuiceFS does not create the directory holding the SQLite database, and SQLite
  # also writes -wal/-shm files next to it, so it must be writable by the mount
  # user. The `mnt` parent is also owned by the user so tmpfiles does not leave a
  # root-owned directory in the home directory.
  systemd.tmpfiles.rules = [
    "d /home/${user}/mnt 0755 ${user} ${group} - -"
    "d ${metaDir} 0750 ${user} ${group} - -"
  ];

  # Same bucket-scoped Garage key the rclone mount used. The material comes from
  # sops at runtime and never enters the nix store.
  sops.secrets.garage-desktop-access-key.key = "garage/desktop-access-key";
  sops.secrets.garage-desktop-secret-key.key = "garage/desktop-secret-key";

  # systemd EnvironmentFile read by both `juicefs format` (ExecStartPre) and
  # `juicefs mount`. JuiceFS' S3 client picks up ACCESS_KEY/SECRET_KEY from it.
  sops.templates.${envTemplate} = {
    content = ''
      ACCESS_KEY=${config.sops.placeholder.garage-desktop-access-key}
      SECRET_KEY=${config.sops.placeholder.garage-desktop-secret-key}
      # Matches s3_region in hosts/server/garage.nix so request signing and the
      # server agree.
      AWS_REGION=garage
    '';
    owner = user;
    group = group;
    mode = "0400";
    restartUnits = [ "juicefs-${volume}.service" ];
  };

  services.juicefs.mounts.${volume} = {
    # `_sync=FULL`: JuiceFS opens SQLite in WAL mode with synchronous=NORMAL by
    # default (see pkg/meta/sql.go), where a power loss or hard crash can drop
    # recently committed metadata even after an application's fsync() returned
    # (JuiceFS documents this explicitly). This is a laptop, so pay the extra WAL
    # fsync per metadata commit and keep POSIX fsync semantics.
    metaUrl = "sqlite3://${metaDir}/${volume}.db?_sync=FULL";
    mountPoint = "/home/${user}/mnt/${volume}";
    user = user;
    group = group;

    # Formats the volume on first start only (guarded by `juicefs status`).
    autoFormat = true;
    format = {
      name = volume;
      storage = "s3";
      # Path-style S3, which is what Garage serves here: `s3_api.root_domain` is
      # not configured for virtual-hosted-style buckets, and JuiceFS defaults to
      # path style unless JFS_S3_VHOST_STYLE is set.
      bucket = "https://s3.waynevanson.com/${bucket}";
      compression = "zstd";
      blockSize = "4M";
      trashDays = 7;
    };

    # 20 GiB local read cache (roughly the old rclone vfs-cache sizing).
    cacheSize = 20 * 1024;

    # Hourly metadata backup into the object store (the JuiceFS default, made
    # explicit). `juicefs restore` rebuilds the SQLite DB from it if the laptop
    # disk is lost.
    backupMeta = "1h";

    environmentFile = config.sops.templates.${envTemplate}.path;
  };
}

# Migrating the old bucket (once, after the first successful switch):
#
#   export AWS_ACCESS_KEY_ID=$(cat /run/secrets/garage-desktop-access-key)
#   export AWS_SECRET_ACCESS_KEY=$(cat /run/secrets/garage-desktop-secret-key)
#   s5cmd --endpoint-url https://s3.waynevanson.com cp 's3://files/*' \
#     /home/waynevanson/mnt/files/
#
# Deleting `files` afterwards is optional; `juicefs gc` and `juicefs fsck` only
# ever look at this volume's own objects in the `juicefs` bucket.
