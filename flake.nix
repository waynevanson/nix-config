{
  inputs = {
    nixpkgs = {
      url = "github:nixos/nixpkgs/nixos-unstable";
    };

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

    nix-minecraft = {
      url = "github:Infinidoge/nix-minecraft";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-openclaw = {
      url = "github:openclaw/nix-openclaw";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      disko,
      home-manager,
      nix-minecraft,
      nix-openclaw,
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
        config = {
          allowUnfree = true;
        };
        overlays = [
          nix-minecraft.overlay
          nix-openclaw.overlays.default
        ];
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

      createAppScripts = pkgs.lib.mapAttrs (
        scriptName: scriptBody: {
          type = "app";
          program = "${pkgs.writeShellScriptBin scriptName scriptBody}/bin/${scriptName}";
        }
      );

      createHomeConfigurations = pkgs.lib.mapAttrs (
        username: profileModule:
        home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          extraSpecialArgs = {
            inherit inputs system;
          };
          modules = [
            profileModule
            {
              home.username = username;
              home.homeDirectory = "/home/${username}";
              home.stateVersion = "25.05";
            }
          ];
        }
      );

    in
    {

      devShells.${system}.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          age
          biome
          nixos-anywhere.packages.${system}.default
          disko.packages.${system}.default
          sops
          ssh-to-age
          yq
        ];
      };

      apps.${system} = createAppScripts {
        server = ''
          nixos-rebuild \
          $1 \
          --flake .#server \
          --build-host waynevanson@waynevanson.com \
          --target-host waynevanson@waynevanson.com \
          --sudo
        '';
      };

      nixosConfigurations = createNixosConfigurations {
        nixos = ./hosts/desktop;
        server = ./hosts/server;
        writer = ./hosts/writer;
      };

      homeModules = {
        waynevanson = ./home-manager/profiles/waynevanson;
        zed = ./home-manager/profiles/zed;
      };

      homeConfigurations = createHomeConfigurations {
        inherit (self.homeModules) waynevanson zed;
      };

      packages.${system} = {
        bitwig = pkgs.callPackage ./packages/bitwig.nix { };
        codelens = pkgs.callPackage ./packages/codelens { };
        pi-catppuccin-themes = pkgs.callPackage ./packages/pi-catppuccin-themes { };
        pi-coding-agent = pkgs.callPackage ./packages/pi-coding-agent { };
      };

      nixosModules = {
        custom = ./modules/custom;
        sops = ./modules/sops.nix;
      };
    };
}
