{
  config,
  lib,
  lib',
  ...
}:
lib'.modularise ["waynevanson" "programs" "zsh"] {
  options.enable = lib.mkEnable {};

  config = {config'}:
    lib.mkIf config'.enable {
      # todo: add ohmyposh or some kind of framework with a plugin system
      programs.zsh = {
        enable = true;
        enableCompletion = true;
        enableBashCompletion = true;
        enableLsColors = true;
      };
    };
}
