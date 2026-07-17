{
  config,
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
  pi-wrapped = pkgs.writeShellApplication {
    name = "pi";
    text = ''
      MOONSHOT_API_KEY="$(${pkgs.coreutils}/bin/tr -d '\n' < ${config.sops.secrets.moonshotai-api-key.path})"
      export MOONSHOT_API_KEY
      KIMI_API_KEY="$MOONSHOT_API_KEY"
      export KIMI_API_KEY
      # export CODELENS_SERVER="${
        inputs.self.packages.${system}.codelens
      }/lib/node_modules/@fodx/codelens/build/src/server.js"
      exec ${pkgs.lib.getExe inputs.self.packages.${system}.pi-coding-agent} "$@"
    '';
  };
  custom' = {
    custom = {
      # virtualisation.docker.enable = true;
      virtualisation.containerd.enable = true;
      services = {
        attic-client.enable = false;
        cosmic.enable = true;
        rclone-mount = {
          # enable = true;
          bucket = "files";
          mountpoint = "/home/waynevanson/cloud";
        };
      };
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
      # Configuration for regular user
      users.waynevanson =
        { self, lib, ... }:
        {
          imports = [ self.homeModules.waynevanson ];
          programs.pi-coding-agent.package = lib.mkForce pi-wrapped;
          home = {
            username = "waynevanson";
            homeDirectory = "/home/waynevanson";
            stateVersion = "25.05";
          };
        };
    };
  };
  system' = {
    # todo: move this somewhere so it's consumed by everything
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
  };
  user' = {
    users = {
      defaultUserShell = pkgs.zsh;
      users.waynevanson = {
        isNormalUser = true;
        description = "Wayne Van Son";
        extraGroups = [
          "audio"
          "video"
          "networkmanager"
          "wheel"
        ];
      };
    };
    programs = {
      zsh.enable = true;
      nix-ld = {
        enable = true;
        # libraries = [];
      };
    };
  };
  # ollama' =
  #   { pkgs, ... }:
  #   {
  #     services.ollama = {
  #       enable = false;
  #       package = pkgs.ollama-cuda;
  #     };
  #   };
  host' = {
    system.stateVersion = "25.05";
    networking.hostName = "nixos"; # Define your hostname.
    boot.loader = {
      efi.canTouchEfiVariables = true;
      systemd-boot.enable = true;
    };
    sops = {
      age.keyFile = "/home/waynevanson/.config/sops/age/keys.txt";
      secrets.moonshotai-api-key = {
        key = "moonshotai/api-key";
        owner = "waynevanson";
        mode = "0400";
      };
    };
  };
in
{
  imports = [
    #./disk-configuration.nix
    ./hardware-configuration.nix
    ../../modules
    self.nixosModules.sops
    hardware'
    host'
    system'
    user'
    homeManager'
    custom'
    # ollama'
  ];
}
