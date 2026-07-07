{
  pkgs,
  self,
  ...
}:
{
  imports = [ self.nixosModules.sops ];
  sops.age.sshKeyPaths = [
    "/etc/ssh/id_ed25519_server"
  ];
  custom.services.attic-client = {
    enable = false;
    server.endpoint = "http://localhost:2884";
  };

  environment.systemPackages = with pkgs; [
    attic-client
    git
    nerd-fonts.jetbrains-mono
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
    # todo: all config.nginx.virtualHosts.* here because server doesn't support hairpinning
    extraHosts = ''
      127.0.0.1 git.waynevanson.com
      127.0.0.1 s3.garage.waynevanson.com
      127.0.0.1 atticd.waynevanson.com
      127.0.0.1 headscale.waynevanson.com
      127.0.0.1 minecraft.waynevanson.com
    '';
    hostId = "0331c65f";
  };
  boot = {
    loader.grub = {
      # no need to set devices, disko will add all devices that have a EF02 partition to the list already
      # devices = [ ];
      efiSupport = true;
      efiInstallAsRemovable = true;
    };
    supportedFilesystems = [ "zfs" ];
    zfs.forceImportRoot = true;
    zfs.forceImportAll = true;
  };
  services = {
    zfs.autoScrub.enable = true;
    sshd.enable = true;
  };

  # Allows use of `--sudo` without a password when running `nixos-rebuild switch`
  security.sudo.wheelNeedsPassword = false;

  # root password only when attached to local
  services.openssh.settings.PermitRootLogin = "prohibit-password";

  # 1
  users.users.root.initialHashedPassword = "$y$j9T$5IMWxJIAFBEzXBlXMSA1./$ru5GH0wRDa1C5btmcAqTXPTd7YrtsHOSakS5hXqVbd0";
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
  i18n = {
    # Select internationalisation properties.
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
