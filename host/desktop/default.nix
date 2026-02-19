{
  lib,
  pkgs,
  ...
}: let
  hardware' = {
    hardware.facter.reportPath = ./facter.json;
  };

  packages = with pkgs; [
    alejandra
    curl
    direnv
    discord
    ghidra
    # todo: modularise
    git
    gnutar
    nerd-fonts.jetbrains-mono
    neofetch
    nfs-utils
    nil
    openscad
    prusa-slicer
    runelite
    tuckr
    unzip
    wget
    vscode.fhs
    xz
    zip
  ];

  waynevanson = {
    virtualisation.docker.enable = true;

    programs.alacritty.enable = true;
    programs.zsh.enable = true;
    programs.bitwig.enable = true;

    nix.enable = true;
  };

  user' = {
    users.users.waynevanson = {
      isNormalUser = true;
      description = "Wayne Van Son";
      extraGroups = ["audio" "video" "networkmanager" "wheel"];
      inherit packages;
    };
  };

  host' = {
    system.stateVersion = "25.05";
  };
in {
  flake.nixosConfigurations.desktop = lib.nixosSystem {
    modules = [
      ./disk-configuration.nix
      hardware'
      host'
      user'
    ];

    inherit waynevanson;
    system = "x86_64-linux";
    environment.systemPackages = packages;
  };
}
