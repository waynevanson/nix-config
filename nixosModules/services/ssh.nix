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

    username = lib.mkOption {
      type = lib.types.str;
      description = "User allowed to login via ssh";
    };
  };

  config = lib.mkIf config.homelab.ssh.enable {
    services.openssh = {
      enable = true;
      ports = [22];
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        PermitRootLogin = "no";
        AllowUsers = [config.homelab.ssh.username];
      };
    };

    services.fail2ban = {
      enable = true;
      maxretry = 5;
      ignoreIP = [
        "192.168.0.0/24"
      ];
    };

    services.endlessh = {
      enable = true;
      port = 22;
      openFirewall = true;
    };
  };
}
