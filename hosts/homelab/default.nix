# NixOS Homelab setup
#
# Setup with `nixos-anywhere`
# `disko` for disk configuration via ZFS
# `agenix` for security/keys
#
# NixOS Modules where available
# Nix containers where applicable
# docker-compose file into nix containers when required
#
# Maybe I should set up all services to run inside of the containers
let
  system' = {
    modulesPath,
    pkgs,
    ...
  }: {
    imports = [
      "${modulesPath}/installer/scan/not-detected.nix"
      "${modulesPath}/profiles/qemu-guest.nix"
    ];

    nix.settings.experimental-features = ["nix-command" "flakes"];

    system.stateVersion = "25.11";

    # `disko` will add devices
    boot.loader.grub = {
      enable = true;
      efiSupport = true;
      efiInstallAsRemovable = true;
    };
    # todo: move this somewhere so it's consumed by everything
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
  };

  network' = {
    networking.nat = {
      enable = true;
      internalInterfaces = ["ve-+"];
      externalInterface = "ens3";
      enableIPv6 = true;
    };

    # other modules will add the ports they need
    networking.firewall.enable = true;
  };

  packages' = {pkgs, ...}: {
    environment.systemPackages = with pkgs; [
      curl
      git
      gnutar
      zip
      unzip
      neofetch
    ];

    programs.zsh = {
      enable = true;
    };
  };

  facter' = {
    hardware.facter.reportPath = ./facter.json;
  };

  modules' = {
    waynevanson = {
      programs.zsh.enable = true;
      programs.tmux.enable = true;
      programs.nixvim.enable = true;
      nix.enable = true;
      programs.direnv.enable = true;
    };

    homelab = {
      services.ssh.enable = true;
      services.acme.enable = true;
      services.nginx.enable = true;
      services.forgejo.enable = true;
      sops.enable = true;
    };
  };
in {
  imports = [
    ./disk-configuration.nix
    ../../modules
    facter'
    modules'
    network'
    packages'
    system'
  ];
}
