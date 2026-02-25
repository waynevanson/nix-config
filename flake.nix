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

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    disko,
    nixpkgs,
    nixvim,
    self,
    sops-nix,
    ...
  } @ inputs: let
    system = "x86_64-linux";

    pkgs = import nixpkgs {
      inherit system;
      config.allowUnfree = true;
    };

    createScriptApps = pkgs.lib.mapAttrs (_appName: appScript: let
      package = pkgs.writeShellScriptBin "run" appScript;
    in {
      type = "app";
      program = "${package}/bin/run";
    });

    createNixosConfigurations = pkgs.lib.mapAttrs (_hostname: hostModule:
      nixpkgs.lib.nixosSystem {
        inherit system pkgs;
        modules = [
          disko.nixosModules.default
          nixvim.nixosModules.nixvim
          sops-nix.nixosModules.sops
          hostModule
        ];
        specialArgs = {inherit inputs;};
      });
  in {
    apps.${system} = createScriptApps {
      install = ''
        nix run github:nix-community/nixos-anywhere -- \
        --flake .#homelab \
        --target-host root@192.168.1.103 \
        -i $1 \
        --generate-hardware-config nixos-facter ./hosts/homelab/facter.json
      '';

      update = ''
        NIX_SSHOPTS="-p 8022" \
        nixos-rebuild switch \
        --flake .#homelab \
        --target-host waynevanson@waynevanson.com \
        --build-host waynevanson@waynevanson.com \
        --sudo \
        --ask-sudo-password
      '';
    };

    devShells.${system}.default = pkgs.mkShell {
      buildInputs = with pkgs; [
        sops
        age
      ];
    };

    nixosConfigurations = createNixosConfigurations {
      bootable = ./hosts/bootable;
      homelab = ./hosts/homelab;
      nixos = ./hosts/desktop;
    };

    packages.${system}.bootable = self.nixosConfigurations.bootable.config.system.build.isoImage;
  };
}
