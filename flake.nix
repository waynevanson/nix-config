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
    createNixosConfigurations = nixpkgs.lib.mapAttrs (
      machineName: modulePath:
        nixpkgs.lib.nixosSystem {
          inherit system pkgs;
          modules = [modulePath];
          specialArgs = {inherit inputs;};
        }
    );
  in {
    packages.x86_64-linux.bootable = self.nixosConfigurations.bootable.config.system.build.isoImage;
    nixosConfigurations = createNixosConfigurations {
      homelab = ./module/machine/homelab;
      bootable = ./module/machine/bootable;
    };
  };
}
