{
  config,
  lib,
  ...
}: {
  options.homelab.ssh = {
    enable = lib.mkEnableOption {
      description = "Enable SSH for HomeLab";
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
        AllowUsers = ["waynevanson"];
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
