{
  config,
  lib,
  pkgs,
  ...
}: let
  configFile = ./alacritty.toml;
  alacritty' = pkgs.symlinkJoin {
    name = "alacritty";
    paths = [pkgs.alacritty];
    buildInputs = [pkgs.makeWrapper];

    postBuild = ''
      wrapProgram $out/bin/alacritty \
      --add-flags "--config-file=${configFile}"
    '';
  };
in {
  options.waynevanson.programs.alacritty.enable = lib.mkEnable {};

  config = lib.mkIf config.waynevanson.programs.alacritty.enable {
    environment.systemPackages = [
      alacritty'
    ];
  };
}
