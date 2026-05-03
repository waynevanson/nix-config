{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-anywhere = {
      url = "github:nix-community/nixos-anywhere";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      disko,
      home-manager,
      nixos-anywhere,
      nixpkgs,
      self,
      sops-nix,
      ...
    }@inputs:
    let
      system = "x86_64-linux";

      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };

      createNixosConfigurations = pkgs.lib.mapAttrs (
        _hostname: hostModule:
        nixpkgs.lib.nixosSystem {
          inherit system pkgs;
          modules = [
            disko.nixosModules.default
            home-manager.nixosModules.default
            sops-nix.nixosModules.sops
            hostModule
          ];
          specialArgs = { inherit inputs system self; };
        }
      );

    in
    {

      devShells.${system}.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          age
          biome
          nixos-anywhere.packages.${system}.default
          sops
          ssh-to-age
          yq
        ];
      };

      nixosConfigurations = createNixosConfigurations {
        nixos = ./hosts/desktop;
      };

       packages.${system} = {
         bitwig = pkgs.callPackage ./packages/bitwig.nix { };
         pi-coding-agent = pkgs.callPackage ./packages/pi.nix { };
       };

       nixosModules.custom = ./modules/custom;
    };
}
