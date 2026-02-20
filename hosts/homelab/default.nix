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
  username = "waynevanson";

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
    # todo: modules from tmux, zsh
    environment.systemPackages = with pkgs; [
      curl
      git
      gnutar
      zip
      unzip
    ];

    programs.tmux = {
      enable = true;
      newSession = true;
      keyMode = "vi";
      baseIndex = 1;
      historyLimit = 99999;
      customPaneNavigationAndResize = true;
      clock24 = true;
      escapeTime = 0;
    };

    programs.zsh = {
      enable = true;
    };
  };

  facter' = {
    hardware.facter.reportPath = ./facter.json;
  };

  homelab' = {
    homelab = {
      user = "waynevanson";
      ssh = {
        enable = true;
        username = "waynevanson";
      };
    };
  };
in {
  imports = [
    ./disk-configuration.nix
    ../../services/ssh.nix
    facter'
    homelab'
    network'
    packages'
    system'
  ];
}
