# System-level JuiceFS volume backed by the Garage S3 bucket `juicefs`.
#
# Layout:
#   * metadata engine: PostgreSQL on the server (`hosts/server/postgresql.nix`),
#     reached through nginx's TCP stream proxy on :2345 and authenticated with
#     the dedicated `postgres.waynevanson.com` certificate. The previous SQLite
#     database at /var/lib/juicefs/files.db is kept as a pre-migration rollback
#     snapshot and is no longer mounted.
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
  metaDb = "juicefs";
  metaDir = "/var/lib/juicefs";
  envTemplate = "juicefs-${volume}-env";
in
{
  # Pin server hostnames to the public address so the mount does not depend on
  # the desktop's DNS setup.
  networking.extraHosts = ''
    115.186.205.123 s3.waynevanson.com
    115.186.205.123 postgres.waynevanson.com
  '';

  # /var/lib/juicefs still holds the pre-Postgres SQLite database (plus its
  # -wal/-shm files), kept for rollback; the mount no longer uses it. The `mnt`
  # parent is owned by the user so tmpfiles does not leave a root-owned
  # directory in the home directory.
  systemd.tmpfiles.rules = [
    "d /home/${user}/mnt 0755 ${user} ${group} - -"
    "d ${metaDir} 0750 ${user} ${group} - -"
  ];

  # Same bucket-scoped Garage key the rclone mount used. The material comes from
  # sops at runtime and never enters the nix store.
  sops.secrets.garage-desktop-access-key.key = "garage/desktop-access-key";
  sops.secrets.garage-desktop-secret-key.key = "garage/desktop-secret-key";

  # Read directly by the mount wrapper (META_PASSWORD) and rendered into the
  # environment file (PGPASSWORD), so it must be readable by the mount user.
  sops.secrets.postgres-juicefs-password = {
    owner = user;
    mode = "0400";
  };

  # systemd EnvironmentFile read by `juicefs mount`. ACCESS_KEY/SECRET_KEY are
  # for the S3 client; PGPASSWORD is read by JuiceFS' pgx driver for the
  # metadata engine. The meta URL itself lives in the world-readable store, so
  # the password must stay here.
  sops.templates.${envTemplate} = {
    content = ''
      ACCESS_KEY=${config.sops.placeholder.garage-desktop-access-key}
      SECRET_KEY=${config.sops.placeholder.garage-desktop-secret-key}
      # Matches s3_region in hosts/server/garage.nix so request signing and the
      # server agree.
      AWS_REGION=garage
      PGPASSWORD=${config.sops.placeholder.postgres-juicefs-password}
    '';
    owner = user;
    group = group;
    mode = "0400";
    restartUnits = [ "juicefs-${volume}.service" ];
  };

  services.juicefs.mounts.${volume} = {
    # Role `juicefs`, database `juicefs`. TLS terminates at Postgres and
    # `verify-full` checks the hostname against the dedicated certificate.
    metaUrl = "postgres://juicefs@postgres.waynevanson.com:2345/${metaDb}?sslmode=verify-full";
    # `META_PASSWORD` (read by the module wrapper) and `PGPASSWORD` (in the
    # environment file below) both carry the same secret, covering whichever
    # one JuiceFS' pgx driver consults.
    metaPasswordFile = config.sops.secrets.postgres-juicefs-password.path;
    mountPoint = "/home/${user}/mnt/${volume}";
    user = user;
    group = group;

    # Never format automatically. With `autoFormat = true`, a transient
    # `juicefs status` failure (e.g. server unreachable) would format a
    # brand-new empty volume against the existing bucket, and a later
    # `juicefs gc` would treat every existing object as unreferenced.
    # Formatting is a deliberate, one-off manual action against a fresh bucket.
    autoFormat = false;

    # 20 GiB local read cache (roughly the old rclone vfs-cache sizing).
    cacheSize = 20 * 1024;

    # Hourly metadata backup into the object store. This backup is
    # engine-independent and can be loaded into a fresh metadata engine with
    # `juicefs load`.
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
# Migrating metadata from the old SQLite engine to Postgres (once):
#
#   systemctl stop juicefs-files.service
#   juicefs dump "sqlite3:///var/lib/juicefs/files.db?_sync=FULL" /var/tmp/files.meta.json
#   export PGPASSWORD="$(cat /run/secrets/postgres-juicefs-password)"
#   export META_PASSWORD="$PGPASSWORD"
#   juicefs load "postgres://juicefs@postgres.waynevanson.com:2345/juicefs?sslmode=verify-full" \
#     /var/tmp/files.meta.json
#   juicefs status "postgres://juicefs@postgres.waynevanson.com:2345/juicefs?sslmode=verify-full"
#   juicefs fsck   "postgres://juicefs@postgres.waynevanson.com:2345/juicefs?sslmode=verify-full"
#
# The Garage objects are untouched by dump/load; only the metadata moves.
