{
  pkgs,
  self,
  ...
}:
{

  imports = [ self.nixosModules.sops ];

  sops.age.sshKeyPaths = [
    "/etc/ssh/ssh_host_ed25519_key"
  ];

  custom.services.attic-client.enable = true;

  environment.systemPackages = with pkgs; [
    git
    nerd-fonts.jetbrains-mono
  ];

  programs.direnv = {
    enable = true;
    silent = true;
  };

  programs.zsh.enable = true;

  networking.hostName = "server";

  # todo: all config.nginx.virtualHosts.* here because server doesn't support hairpinning
  networking.extraHosts = ''
    127.0.0.1 git.waynevanson.com
    127.0.0.1 s3.garage.waynevanson.com
    127.0.0.1 atticd.waynevanson.com
    127.0.0.1 headscale.waynevanson.com
    127.0.0.1 minecraft.waynevanson.com
  '';

  boot.loader.grub = {
    # no need to set devices, disko will add all devices that have a EF02 partition to the list already
    # devices = [ ];
    efiSupport = true;
    efiInstallAsRemovable = true;
  };

  boot.supportedFilesystems = [ "zfs" ];

  boot.zfs.forceImportRoot = false;

  networking.hostId = "0331c65f";

  services.zfs.autoScrub.enable = true;
  #
  # Allows use of `--sudo` without a password when running `nixos-rebuild switch`
  security.sudo.wheelNeedsPassword = false;

  users.users.waynevanson = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDVwuz7O5uHh6blzTrfETNz5omxutdgiPTrl+PKNcgSa waynevanson@nixos"
    ];
  };

  system.stateVersion = "26.05";

  # Set your time zone.
  time.timeZone = "Australia/Melbourne";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_AU.UTF-8";

  i18n.extraLocaleSettings = {
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

  services.sshd.enable = true;
}
