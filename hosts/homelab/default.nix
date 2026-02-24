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

  waynevanson = {
    programs.zsh.enable = true;
    programs.tmux.enable = true;
    programs.nixvim.enable = true;
    nix.enable = true;
    programs.direnv.enable = true;
  };

  homelab = {
    ssh.enable = true;
    nginx.enable = true;
    services.git.enable = true;
  };
in {
  imports = [
    ./disk-configuration.nix
    ../../modules
    facter'
    network'
    packages'
    system'
  ];

  inherit homelab waynevanson;
}
