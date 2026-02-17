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
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    disko,
    flake-utils,
    nixpkgs,
    self,
    ...
  } @ inputs: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {inherit system;};
    hostname = "homelab";
    username = "waynevanson";

    system' = {
      modulesPath,
      pkgs,
      # --arg bootable true
      bootable ? false,
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

      users.users.${username} = {
        isNormalUser = true;
        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDVwuz7O5uHh6blzTrfETNz5omxutdgiPTrl+PKNcgSa waynevanson@nixos"
        ];
        extraGroups = [
          "wheel"
          "networkmanager"
          "video"
          "render"
        ];
      };

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

      networking.nat = {
        enable = true;
        internalInterfaces = ["ve-+"];
        externalInterface = "ens3";
        enableIPv6 = true;
      };

      # other modules will do their thing
      networking.firewall.enable = true;
    };

    homelab' = {
      imports = [
        ./disk-configuration.nix
        ./ssh.nix
        {
          hardware.facter.reportPath = ./facter.json;
        }
        system'
      ];

      homelab = {
        ssh = {
          enable = true;
          port = 8022;
          username = "waynevanson";
        };
      };
    };
  in {
    packages.${system}.bootable = self.nixosConfigurations.bootable.config.system.build.isoImage;
    nixosConfigurations = {
      ${hostname} = nixpkgs.lib.nixosSystem {
        inherit system pkgs;
        specialArgs = {inherit inputs;};
        modules = [homelab'];
      };
      bootable = nixpkgs.lib.nixosSystem {
        inherit system pkgs;
        specialArgs = {inherit inputs;};
        modules = [./machine/bootable.nix];
      };
    };
  };
}
