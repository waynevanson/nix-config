{
  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # If using a stable channel you can use `url = "github:nix-community/nixvim/nixos-<version>"`
    nixvim.url = "github:nix-community/nixvim";
    nixvim.inputs.nixpkgs.follows = "nixpkgs";

    wrappers.url = "github:lassulus/wrappers";
    wrappers.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = {
    flake-utils,
    nixpkgs,
    nixvim,
    ...
  } @ inputs: let
    system' = {pkgs, ...}: {
      fonts.fontconfig.enable = true;

      # don't change this unless on a new system.
      system.stateVersion = "25.05";
    };

    # user level packages
    waynevanson' = {pkgs, ...}: let
      packages = with pkgs; [
        alejandra
        bitwig'
        curl
        direnv
        discord
        ghidra
        git
        gnutar
        nerd-fonts.jetbrains-mono
        neofetch
        nfs-utils
        nil
        openscad
        prusa-slicer
        runelite
        tuckr
        unzip
        wget
        vscode.fhs
        xz
        zip
      ];
    in {
      # Define a user account. Don't forget to set a password with ‘passwd’.
      users.users.waynevanson = {
        isNormalUser = true;
        description = "Wayne Van Son";
        extraGroups = ["audio" "video" "networkmanager" "wheel"];
        inherit packages;
      };
    };
  in
    flake-utils.lib.eachDefaultSystemPassThrough (system: let
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    in {
      nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
        inherit pkgs system;

        specialArgs = {
          inherit inputs;
        };

        modules = [
          nixvim.nixosModules.nixvim
          locale'
          system'
          waynevanson'
          ./nix
        ];
      };
    });
}
