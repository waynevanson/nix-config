# Declaratively provision Garage S3 access keys and their bucket permissions.
#
# Garage has no declarative config for keys (only the bootstrap
# GARAGE_DEFAULT_ACCESS_KEY / GARAGE_DEFAULT_BUCKET), so this module drives the
# `garage` CLI from a oneshot unit instead. Key material is read from files (in
# this repo: sops-rendered secrets), which makes the keys reproducible and lets
# other hosts be handed the same credentials.
#
# Garage >= 2.x's CLI proxies its requests to a node over RPC, so nothing here
# needs the Admin API, an admin token, or an exposed admin socket - only the RPC
# secret (supplied through `environmentFile`).
#
# Everything is idempotent: keys are imported only when missing, buckets are
# created only when missing, permissions/quotas are set unconditionally.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.custom.services.garage-client-keys;

  # `--read`, `--write`, `--owner`, ... from the submodule's permission flags.
  permFlags = perms: lib.concatStrings (lib.mapAttrsToList (n: v: lib.optionalString v " --${n}") perms);

  quotaArgs =
    quota:
    lib.optional (quota.maxSize != null) "--max-size ${lib.escapeShellArg quota.maxSize}"
    ++ lib.optional (quota.maxObjects != null) "--max-objects ${lib.escapeShellArg quota.maxObjects}";

  keyName = name: cfg.keys.${name}.name;

  keySteps = lib.mapAttrsToList (_: key: ''
    if ! garage key info ${lib.escapeShellArg key.name} >/dev/null 2>&1; then
      echo "importing garage key ${key.name}"
      garage key import \
        "$(cat ${lib.escapeShellArg key.accessKeyFile})" \
        "$(cat ${lib.escapeShellArg key.secretKeyFile})" \
        --yes -n ${lib.escapeShellArg key.name}
    ${lib.optionalString (key.expiresIn != null) ''
        garage key set --expires-in ${lib.escapeShellArg key.expiresIn} ${lib.escapeShellArg key.name}
    ''}
    fi
    ${lib.optionalString key.createBucket ''
      garage key allow --create-bucket ${lib.escapeShellArg key.name}
    ''}
  '') cfg.keys;

  bucketSteps = lib.mapAttrsToList (bucket: b: ''
    ${lib.optionalString b.create ''
      if ! garage bucket info ${lib.escapeShellArg bucket} >/dev/null 2>&1; then
        echo "creating garage bucket ${bucket}"
        garage bucket create ${lib.escapeShellArg bucket}
      fi
    ''}
    ${lib.concatStringsSep "\n" (
      lib.mapAttrsToList (name: perms: ''
        garage bucket allow${permFlags perms} ${lib.escapeShellArg bucket} \
          --key ${lib.escapeShellArg (keyName name)}
      '') b.keys
    )}
    ${lib.optionalString ((quotaArgs b.quotas) != [ ]) ''
      garage bucket set-quotas ${lib.escapeShellArg bucket} \
        ${lib.concatStringsSep " " (quotaArgs b.quotas)}
    ''}
  '') cfg.buckets;

  script = pkgs.writeShellScript "garage-client-keys" ''
    set -eu

    # The CLI talks to the daemon over RPC, so wait for it to answer first.
    tries=$(( ${toString cfg.waitTimeout} / 2 + 1 ))
    i=0
    until garage status >/dev/null 2>&1; do
      i=$((i + 1))
      if [ "$i" -ge "$tries" ]; then
        echo "garage daemon did not answer within ${toString cfg.waitTimeout}s" >&2
        exit 1
      fi
      sleep 2
    done

    ${lib.concatStringsSep "\n" keySteps}

    ${lib.concatStringsSep "\n" bucketSteps}
  '';
in
{
  options.custom.services.garage-client-keys = {
    enable = lib.mkEnableOption "declarative Garage S3 keys and bucket permissions";

    package = lib.mkOption {
      type = lib.types.package;
      default = if config.services.garage.enable then config.services.garage.package else pkgs.garage_2;
      defaultText = lib.literalExpression "config.services.garage.package";
      description = "Garage package providing the `garage` CLI.";
    };

    environmentFile = lib.mkOption {
      type = with lib.types; nullOr str;
      default =
        if config.services.garage.enable && config.services.garage.environmentFile != null then
          toString config.services.garage.environmentFile
        else
          null;
      defaultText = lib.literalExpression "config.services.garage.environmentFile";
      description = ''
        File with the environment the CLI needs, at minimum `GARAGE_RPC_SECRET`.
        Defaults to the running daemon's environment file.
      '';
    };

    waitTimeout = lib.mkOption {
      type = lib.types.ints.positive;
      default = 120;
      description = "Seconds to wait for the Garage daemon to answer before failing.";
    };

    keys = lib.mkOption {
      default = { };
      description = ''
        Access keys to import. Key permissions are granted per bucket in
        {option}`buckets`.
      '';
      type = lib.types.attrsOf (
        lib.types.submodule (
          { name, ... }:
          {
            options = {
              name = lib.mkOption {
                type = lib.types.str;
                default = name;
                description = "Name of the key inside Garage (defaults to the attribute name).";
              };

              accessKeyFile = lib.mkOption {
                type = lib.types.path;
                description = ''
                  File containing the access key ID to import. Must be a runtime
                  path (e.g. a sops-rendered secret); a Nix path literal would be
                  copied into the world-readable nix store instead.
                '';
                example = lib.literalExpression "config.sops.secrets.garage-desktop-access-key.path";
              };

              secretKeyFile = lib.mkOption {
                type = lib.types.path;
                description = ''
                  File containing the secret access key to import. Same caveat as
                  {option}`accessKeyFile`.
                '';
                example = lib.literalExpression "config.sops.secrets.garage-desktop-secret-key.path";
              };

              createBucket = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Allow the key to create buckets via S3's `CreateBucket`.";
              };

              expiresIn = lib.mkOption {
                type = with lib.types; nullOr str;
                default = null;
                example = "90d";
                description = ''
                  Expiry applied when the key is first imported (Garage's
                  `--expires-in` syntax). Ignored for keys that already exist, so
                  that re-running the unit does not keep extending the expiry.
                '';
              };
            };
          }
        )
      );
    };

    buckets = lib.mkOption {
      default = { };
      description = ''
        Buckets to ensure, with the keys allowed on each. Bucket names are the
        attribute names.
      '';
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            create = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Create the bucket if it does not exist yet.";
            };

            keys = lib.mkOption {
              type = lib.types.attrsOf (
                lib.types.submodule {
                  options = {
                    read = lib.mkOption {
                      type = lib.types.bool;
                      default = false;
                      description = "Allow read operations (--read).";
                    };
                    write = lib.mkOption {
                      type = lib.types.bool;
                      default = false;
                      description = "Allow write operations (--write).";
                    };
                    owner = lib.mkOption {
                      type = lib.types.bool;
                      default = false;
                      description = "Allow administrative operations on the bucket (--owner).";
                    };
                  };
                }
              );
              default = { };
              description = "Keys allowed on this bucket; names must exist in {option}`keys`.";
            };

            quotas = {
              maxSize = lib.mkOption {
                type = with lib.types; nullOr str;
                default = null;
                example = "100GiB";
                description = "Maximum bucket size (Garage syntax, or `none` to clear).";
              };
              maxObjects = lib.mkOption {
                type = with lib.types; nullOr str;
                default = null;
                example = "100000";
                description = "Maximum number of objects (or `none` to clear).";
              };
            };
          };
        }
      );
    };
  };

  config = lib.mkIf cfg.enable {
    assertions =
      map
        (bucket: {
          assertion = lib.all (name: cfg.keys ? ${name}) (lib.attrNames cfg.buckets.${bucket}.keys);
          message = "custom.services.garage-client-keys: bucket `${bucket}` references a key that is not declared in `keys`";
        })
        (lib.attrNames cfg.buckets)
      ++ map
        (bucket: {
          assertion = lib.all (
            name: lib.any (p: cfg.buckets.${bucket}.keys.${name}.${p}) [ "read" "write" "owner" ]
          ) (lib.attrNames cfg.buckets.${bucket}.keys);
          message = "custom.services.garage-client-keys: bucket `${bucket}` allows a key with no permissions set";
        })
        (lib.attrNames cfg.buckets);

    systemd.services.garage-client-keys = {
      description = "Provision Garage S3 keys and bucket permissions";
      wantedBy = [ "multi-user.target" ];
      wants = [ "garage.service" ];
      after = [ "garage.service" ];
      path = [
        cfg.package
        pkgs.coreutils
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        EnvironmentFile = lib.optional (cfg.environmentFile != null) cfg.environmentFile;
        ExecStart = script;
      };
    };
  };
}
