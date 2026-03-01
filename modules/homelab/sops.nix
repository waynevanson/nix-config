{
  config,
  lib,
  ...
}: let
  config' = config.homelab.sops;
in {
  options.homelab.sops.enable = lib.mkEnableOption {};

  config = lib.mkIf config'.enable {
    sops.defaultSopsFile = ../../.sops.secrets.yaml;
  };
}
