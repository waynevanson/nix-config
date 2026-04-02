{
  pkgs,
  inputs,
  system,
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
    nfs-utils
    nil
    inputs.opencode.packages.${system}.default
    openscad
    prusa-slicer
    runelite
    tuckr
    unzip
    wget
    vscode.fhs
    xz
    zed-editor.fhs
    zip
  ];

  waynevanson = {
    # virtualisation.docker.enable = true;
    virtualisation.containerd.enable = true;

    programs.zsh.enable = true;
    programs.bitwig.enable = true;
    programs.nixvim.enable = true;
    programs.tmux.enable = true;
    programs.direnv.enable = true;

    services.cosmic.enable = true;

    nix.enable = true;
  };

  # Home Manager configuration for both users
  homeManager = {
    # Use global pkgs and enable user packages
    home-manager.useGlobalPkgs = true;
    home-manager.useUserPackages = true;

    # Configuration for regular user
    home-manager.users.waynevanson = {...}: {
      imports = [../../home-manager];

      home = {
        username = "waynevanson";
        homeDirectory = "/home/waynevanson";
        stateVersion = "25.05";
      };

      programs.home-manager.enable = true;
    };
  };

  system' = {
    programs.firefox.enable = true;

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

  user' = {
    users.users.waynevanson = {
      isNormalUser = true;
      description = "Wayne Van Son";
      extraGroups = ["audio" "video" "networkmanager" "wheel"];
      inherit packages;
    };

    # mount /mnt/secondary to /home/waynevanson/code
    # systemd.tmpfiles.settings = {
    #   "waynevanson-code" = {
    #     "/home/waynevanson/code".d = {
    #       type = "L";
    #       user = "waynevanson";
    #       group = "users";
    #       argument = "/mnt/secondary";
    #     };
    #   };
    # };

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

  host' = {
    system.stateVersion = "25.05";

    networking.hostName = "nixos"; # Define your hostname.

    boot.loader = {
      efi.canTouchEfiVariables = true;
      systemd-boot.enable = true;
    };
  };
in {
  imports = [
    #./disk-configuration.nix
    ./hardware-configuration.nix
    ../../modules
    hardware'
    host'
    system'
    user'
    homeManager
  ];

  inherit waynevanson;
  environment.systemPackages = packages;
}
