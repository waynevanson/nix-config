{
  config,
  lib,
  ...
}: {
  options.waynevanson.programs.zsh.enable = lib.mkEnable {};

  config = lib.mkIf config.waynevanson.programs.zsh.enable {
    # todo: add ohmyposh or some kind of framework with a plugin system
    programs.zsh = {
      enable = true;
      enableCompletion = true;
      enableBashCompletion = true;
      enableLsColors = true;
    };
  };
}
