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
    ...
  } @ inputs: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {
      inherit system;
      config.allowUnfree = true;
    };
    specialArgs = {inherit inputs;};
  in {
    nixosModules = {};
    nixosConfigurations = {
      nixos = nixpkgs.lib.nixosSystem {
        inherit system pkgs specialArgs;
        modules = [
          disko.nixosModules.default
          nixvim.nixosModules.nixvim
          ./hosts/desktop
        ];
      };
      # homelab = nixpkgs.lib.nixosSystem {
      #   inherit system pkgs specialArgs;
      #   modules = [
      #     disko.nixosModules.default
      #     # ./hosts/homelab
      #   ];
      # };
    };
  };
}
