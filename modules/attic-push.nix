{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.custom.attic.push;
in
{
  options.custom.attic.push = {
    enable = lib.mkEnableOption "Attic post-build push hook";

    server = lib.mkOption {
      type = lib.types.str;
      default = "atticd";
      description = "Alias name for the Attic server in the generated client config.";
    };

    endpoint = lib.mkOption {
      type = lib.types.str;
      default = "https://atticd.waynevanson.com/";
      description = "Attic server API endpoint.";
    };

    cache = lib.mkOption {
      type = lib.types.str;
      default = "default";
      description = "Attic cache to push newly-built store paths to.";
    };

    tokenFile = lib.mkOption {
      type = lib.types.path;
      default = "/etc/attic/push-token";
      description = "Path to a file containing the Attic push token.";
    };
  };

  config = lib.mkIf cfg.enable {
    nix.settings.post-build-hook = toString (
      pkgs.writeShellScript "attic-post-build-hook" ''
        set -eu

        token_file=${lib.escapeShellArg cfg.tokenFile}

        if [ ! -r "$token_file" ]; then
          echo "attic-post-build-hook: $token_file is not readable, skipping push" >&2
          exit 0
        fi

        tmpdir=$(mktemp -d)
        trap 'rm -rf "$tmpdir"' EXIT

        mkdir -p "$tmpdir/attic"
        cat > "$tmpdir/attic/config.toml" <<EOF
        default-server = ${lib.escapeShellArg cfg.server}

        [servers.${cfg.server}]
        endpoint = ${lib.escapeShellArg cfg.endpoint}
        token = "$(tr -d '\n' < "$token_file")"
        EOF

        export XDG_CONFIG_HOME="$tmpdir"

        ${lib.getExe pkgs.attic-client} push ${lib.escapeShellArg cfg.cache} $OUT_PATHS || true
      ''
    );
  };
}
