{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.custom.services.opencode.server;

  args =
    [ "serve" "--port" (toString cfg.port) "--hostname" cfg.hostname ]
    ++ optional cfg.mdns "--mdns"
    ++ concatMap (origin: [ "--cors" origin ]) cfg.cors;
in
{
  options.custom.services.opencode.server = {
    enable = mkEnableOption "OpenCode server";

    package = mkOption {
      type = types.package;
      default = pkgs.opencode;
      description = "OpenCode package to use.";
    };

    port = mkOption {
      type = types.port;
      default = 4096;
      description = "Port for the OpenCode server to listen on.";
    };

    hostname = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "Hostname for the OpenCode server to bind to.";
    };

    mdns = mkOption {
      type = types.bool;
      default = false;
      description = "Enable mDNS service discovery.";
    };

    cors = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Additional allowed CORS origins.";
    };

    nginx = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Expose OpenCode via nginx reverse proxy.";
      };

      hostName = mkOption {
        type = types.str;
        default = "opencode.waynevanson.com";
        description = "Subdomain used to expose OpenCode.";
      };
    };
  };

  config = mkIf cfg.enable {
    users.groups.opencode = { };
    users.users.opencode = {
      isSystemUser = true;
      group = "opencode";
      home = "/var/lib/opencode";
    };

    systemd.services.opencode-server = {
      description = "OpenCode server";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        Type = "simple";
        User = "opencode";
        Group = "opencode";
        StateDirectory = "opencode";
        WorkingDirectory = "/var/lib/opencode";
        Environment = [ "HOME=/var/lib/opencode" ];
        ExecStartPre = pkgs.writeShellScript "opencode-password-setup" ''
          install -d -m 700 /var/lib/opencode/.local/state/opencode
          ${pkgs.coreutils}/bin/tr -d '\n' < ${config.sops.secrets.opencode-server-password.path} \
            > /var/lib/opencode/.local/state/opencode/password
          chmod 600 /var/lib/opencode/.local/state/opencode/password
        '';
        ExecStart = "${cfg.package}/bin/opencode ${escapeShellArgs args}";
        Restart = "on-failure";
      };
    };

    services.nginx.virtualHosts.${cfg.nginx.hostName} = mkIf cfg.nginx.enable {
      useACMEHost = "waynevanson.com";
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://${cfg.hostname}:${toString cfg.port}";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_max_temp_file_size 0;
          client_max_body_size 0;
        '';
      };
    };
  };
}
