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

    createNixosConfigurations = pkgs.lib.mapAttrs (_hostname: hostModule:
      nixpkgs.lib.nixosSystem {
        inherit system pkgs;
        modules = [
          disko.nixosModules.default
          nixvim.nixosModules.nixvim
          hostModule
        ];
        specialArgs = {inherit inputs;};
      });
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

    nixosConfigurations = createNixosConfigurations {
      bootable = ./hosts/bootable;
      homelab = ./hosts/homelab;
      nixos = ./hosts/desktop;
    };
  };
}
