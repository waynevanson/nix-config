{ pkgs, ... }:
{
  # .sops.yaml encrypts to this host key's age recipient. Preserve it across
  # reinstalls with `nixos-anywhere --copy-host-keys`, otherwise NixOS will
  # generate a new key and sops secrets will no longer decrypt.
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  environment.systemPackages = with pkgs; [
    git
    lvm2
    minio-client
    smartmontools
  ];

  programs = {
    direnv = {
      enable = true;
      silent = true;
    };
    zsh.enable = true;
  };

  networking = {
    hostName = "server";
    hostId = "0331c65f";
    extraHosts = ''
      127.0.0.1 s3.waynevanson.com
    '';
  };

  boot = {
    loader.grub = {
      efiSupport = true;
      efiInstallAsRemovable = true;
    };
    initrd.kernelModules = [
      "dm-raid"
      "raid456"
    ];
    kernelModules = [
      "dm-raid"
      "raid456"
    ];
  };

  services = {
    fstrim.enable = true;
    lvm.dmeventd.enable = true;
    openssh.enable = true;
    smartd.enable = true;
  };

  # Allows `nixos-rebuild switch --sudo` without a password.
  security.sudo.wheelNeedsPassword = false;

  # Root password only when attached to the local console.
  services.openssh.settings.PermitRootLogin = "prohibit-password";
  users.users.root.initialHashedPassword = "$y$j9T$5IMWxJIAFBEzXBlXMSA1./$ru5GH0wRDa1C5btmcAqTXPTd7YrtsHOSakS5hXqVbd0";
  users.users.waynevanson = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDVwuz7O5uHh6blzTrfETNz5omxutdgiPTrl+PKNcgSa waynevanson@nixos"
    ];
  };

  system.stateVersion = "26.05";
  time.timeZone = "Australia/Melbourne";

  i18n = {
    defaultLocale = "en_AU.UTF-8";
    extraLocaleSettings = {
      LC_ADDRESS = "en_AU.UTF-8";
      LC_IDENTIFICATION = "en_AU.UTF-8";
      LC_MEASUREMENT = "en_AU.UTF-8";
      LC_MONETARY = "en_AU.UTF-8";
      LC_NAME = "en_AU.UTF-8";
      LC_NUMERIC = "en_AU.UTF-8";
      LC_PAPER = "en_AU.UTF-8";
      LC_TELEPHONE = "en_AU.UTF-8";
      LC_TIME = "en_AU.UTF-8";
    };
  };
}
