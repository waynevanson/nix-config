{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.custom.services.attic-client;
  configFile = pkgs.writeText "attic-config.toml" ''
    default-server = "${cfg.server.name}"

    [servers.${cfg.server.name}]
    endpoint = "${cfg.server.endpoint}"
    token-file = "${config.sops.secrets.${cfg.tokenSecret}.path}"
  '';
in
{
  options.custom.services.attic-client = {
    enable = mkEnableOption "Attic client watch-store service";

    package = mkOption {
      type = types.package;
      default = pkgs.attic-client;
      description = "Attic client package to use.";
    };

    cache = mkOption {
      type = types.str;
      default = "default";
      description = "Attic cache to push store paths to.";
    };

    server = {
      name = mkOption {
        type = types.str;
        default = "default";
        description = "Name of the Attic server in the client config.";
      };

      endpoint = mkOption {
        type = types.str;
        default = "https://atticd.waynevanson.com";
        description = "Attic server API endpoint.";
      };
    };

    tokenSecret = mkOption {
      type = types.str;
      default = "attic-client-token";
      description = "Name of the sops secret containing the Attic access token.";
    };
  };

  config = mkIf cfg.enable {
    sops.secrets.${cfg.tokenSecret}.restartUnits = [ "attic-client.service" ];

    systemd.tmpfiles.rules = [
      "d /root/.config/attic 0700 root root -"
      "L+ /root/.config/attic/config.toml - root root - ${configFile}"
    ];

    sops.templates.attic-client-environment = {
      content = ''
        ATTIC_TOKEN=${config.sops.placeholder.${cfg.tokenSecret}}
        ATTIC_SERVER=${cfg.server.endpoint}
      '';
    };

    systemd.services.attic-client = {
      description = "Attic client watch-store service";
      wantedBy = [ "multi-user.target" ];
      after = [
        "network-online.target"
        "nix-daemon.service"
      ];
      wants = [ "network-online.target" ];

      serviceConfig = {
        Type = "simple";
        User = "root";
        Group = "root";
        StateDirectory = "attic-client";
        WorkingDirectory = "/var/lib/attic-client";
        Environment = [
          "HOME=/var/lib/attic-client"
          "XDG_CONFIG_HOME=/var/lib/attic-client/.config"
        ];
        EnvironmentFile = config.sops.templates.attic-client-environment.path;
        ExecStartPre = pkgs.writeShellScript "attic-client-config" ''
          install -d -m 700 /var/lib/attic-client/.config/attic
          install -m 600 ${configFile} /var/lib/attic-client/.config/attic/config.toml
        '';
        ExecStart = "${cfg.package}/bin/attic watch-store ${escapeShellArg cfg.cache}";
        Restart = "on-failure";
      };
    };
  };
}
