{
  config,
  lib,
  pkgs,
  ...
}: let
  # Workaround for https://github.com/NixOS/nixpkgs/issues/446226
  bitwig' = pkgs.bitwig-studio.override {
    bitwig-studio-unwrapped = pkgs.bitwig-studio5-unwrapped.overrideAttrs rec {
      version = "5.0.11";
      src = pkgs.fetchurl {
        name = "bitwig-studio-${version}.deb";
        url = "https://downloads.bitwig.com/${version}/bitwig-studio-${version}.deb";
        hash = "sha256-c9bRWVWCC9hLxmko6EHgxgmghrxskJP4PQf3ld2BHoY=";
      };
    };
  };
in {
  options.waynevanson.programs.bitwig.enable = lib.mkEnable {};

  config = lib.mkIf config.waynevanson.programs.bitwig.enable {
    environment.systemPackages = [bitwig'];
  };
}
