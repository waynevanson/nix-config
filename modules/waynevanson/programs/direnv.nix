{
  config,
  lib,
  ...
}: let
  config' = config.waynevanson.programs.direnv;
in {
  options.waynevanson.programs.direnv.enable = lib.mkEnableOption {};

  config = lib.mkIf config'.enable {
    programs.direnv = {
      enable = true;
      silent = true;
    };
  };
}
