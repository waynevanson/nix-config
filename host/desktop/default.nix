{lib, ...}: let
  hardware' = {};
  system' = {
    waynevanson = {
      virtualisation.docker.enable = true;
      programs = {
        alacritty.enable = true;
        zsh.enable = true;
      };
      services = {};
      nix.enable = true;
    };
  };
in {
  imports = [
    {
      hardware.facter.reportPath = ./facter.json;
    }
    ./disk-configuration.nix
  ];

  flake.nixosConfigurations.desktop = lib.nixosSystem {
    system = "x86_64-linux";
  };
}
