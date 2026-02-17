{
  config,
  lib,
  pkgs,
  ...
}: {
  options.homelab.ssh = {
    enable = lib.mkEnableOption {
      description = "Enable SSH for HomeLab";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 22;
      description = "Port number for SSH. If not 22, replaces 22 with ssh";
    };

    username = lib.mkOption {
      type = lib.types.str;
      description = "User allowed to login via ssh";
    };
  };

  config = let
    cfg = config.homelab.ssh;
  in
    lib.mkIf cfg.enable {
      services.openssh = {
        enable = true;
        ports = [cfg.port];
        settings = {
          PasswordAuthentication = false;
          KbdInteractiveAuthentication = false;
          PermitRootLogin = "no";
          AllowUsers = [cfg.username];
        };
      };

      networking.firewall = {
        enable = true;
        allowedTCPPorts = [cfg.port];
      };

      services.fail2ban = {
        enable = true;
        maxretry = 5;
        ignoreIP = [
          "192.168.0.0/24"
        ];
      };

      services.endlessh = lib.mkIf (cfg.port != 22) {
        enable = true;
        port = 22;
        openFirewall = true;
      };
    };
}
