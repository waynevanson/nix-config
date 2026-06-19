{
  pkgs,
  inputs,
  system,
  self,
  ...
}:
let
  hardware' = {
    hardware.facter.reportPath = ./facter.json;
  };

  custom' = {
    custom = {
      # virtualisation.docker.enable = true;
      virtualisation.containerd.enable = true;
      services.cosmic.enable = true;
    };
  };

  # Home Manager configuration for both users
  homeManager' = {
    # Use global pkgs and enable user packages
    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      extraSpecialArgs = {
        inherit inputs system self;
      };
    };

    # Configuration for regular user
    home-manager.users.waynevanson =
      { self, ... }:
      {
        imports = [ self.homeModules.waynevanson ];

        home = {
          username = "waynevanson";
          homeDirectory = "/home/waynevanson";
          stateVersion = "25.05";
        };
      };
  };

  system' = {
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
    users.defaultUserShell = pkgs.zsh;
    programs.zsh.enable = true;

    users.users.waynevanson = {
      isNormalUser = true;
      description = "Wayne Van Son";
      extraGroups = [
        "audio"
        "video"
        "networkmanager"
        "wheel"
      ];
    };

    programs.nix-ld = {
      enable = true;
      # libraries = [];
    };
  };

  ollama' =
    { pkgs, ... }:
    {
      services.ollama = {
        enable = true;
        package = pkgs.ollama-cuda;
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
in
{
  imports = [
    #./disk-configuration.nix
    ./hardware-configuration.nix
    ../../modules
    hardware'
    host'
    system'
    user'
    homeManager'
    custom'
    ollama'
  ];
}
