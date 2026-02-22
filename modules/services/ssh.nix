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
      ports = [8022];
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

    security.sudo.wheelNeedsPassword = false;

    # users.users.audience = {
    #   hashedPassword = "$6$q/jbmzAMGAbH0yro$Htz8D5erZg45CQ1VlJ3SweKNxNYVcjSg/bseMhKcnnJgqziyTtScaVLhaRMl/lmFFbeg/QQeyx8wVxrDcnX.o/";
    #   isNormalUser = true;
    # };

    # services.getty.autologinUser = "audience";

    users.users.waynevanson = {
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDVwuz7O5uHh6blzTrfETNz5omxutdgiPTrl+PKNcgSa waynevanson@nixos"
      ];
      isNormalUser = true;
      extraGroups = ["wheel" "networkmanager"];
    };
  };
}
