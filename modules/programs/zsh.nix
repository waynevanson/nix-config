{
  config,
  lib,
  ...
}: let
  config' = config.waynevanson.programs.zsh;
in {
  options.waynevanson.programs.zsh.enable = lib.mkEnableOption {};

  config = lib.mkIf config'.enable {
    # todo: add ohmyposh or some kind of framework with a plugin system
    programs.zsh = {
      enable = true;
      enableCompletion = true;
      enableBashCompletion = true;
      enableLsColors = true;
    };
  };
}
