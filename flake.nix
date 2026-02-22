# NixOS Homelab setup
#
# Setup with `nixos-anywhere`
# `disko` for disk configuration via ZFS
# `agenix` for security/keys
#
# NixOS Modules where available
# Nix containers where applicable
# docker-compose file into nix containers when required
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    disko,
    nixpkgs,
    nixvim,
    self,
    ...
  } @ inputs: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {
      inherit system;
      config.allowUnfree = true;
    };
    specialArgs = {inherit inputs;};

    apps = {
      install = pkgs.writeShellScriptBin "run" ''
        nix run github:nix-community/nixos-anywhere -- \
        --flake .#homelab \
        --target-host root@192.168.1.103 \
        -i $1 \
        --generate-hardware-config nixos-facter ./hosts/homelab/facter.json
      '';
      update = pkgs.writeShellScriptBin "run" ''
        NIX_SSHOPTS="-p 8022" \
        nixos-rebuild switch \
        --flake .#homelab \
        --target-host waynevanson@192.168.1.103 \
        --sudo
      '';
    };
  in {
    apps.${system} = {
      install = {
        type = "app";
        program = "${apps.install}/bin/run";
      };

      update = {
        type = "app";
        program = "${apps.update}/bin/run";
      };
    };

    packages.${system}.bootable = self.nixosConfigurations.bootable.config.system.build.isoImage;

    nixosConfigurations = {
      nixos = nixpkgs.lib.nixosSystem {
        inherit system pkgs specialArgs;
        modules = [
          disko.nixosModules.default
          nixvim.nixosModules.nixvim
          ./hosts/desktop
        ];
      };

      homelab = nixpkgs.lib.nixosSystem {
        inherit system pkgs specialArgs;
        modules = [
          disko.nixosModules.default
          # this doesn't use nixvim but still needs acces to the module to consider it's options.
          nixvim.nixosModules.nixvim
          ./hosts/homelab
        ];
      };

      bootable = nixpkgs.lib.nixosSystem {
        inherit system pkgs specialArgs;

        modules = [
          # this doesn't use nixvim but still needs acces to the module to consider it's options.
          disko.nixosModules.default
          # this doesn't use nixvim but still needs acces to the module to consider it's options.
          nixvim.nixosModules.nixvim
          ./hosts/bootable
        ];
      };
    };
  };
}
