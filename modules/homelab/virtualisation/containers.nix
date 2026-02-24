{
  config,
  lib,
  ...
}: let
  config' = config.homelab.virtualisation.containers;
in {
  options.homelab.virtualisation.containers = {
    enable = lib.mkEnableOption {};
  };

  config =
    lib.mkIf config'.enable {
    };
}
