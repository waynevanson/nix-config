{
  config,
  lib,
  ...
}: let
  config' = config.homelab.sops;
in {
  options.homelab.sops.enable = lib.mkEnableOption {};

  config = lib.mkIf config'.enable {
    sops.defaultSopsFile = ../../secrets/main.yaml;
    sops.age = {
      generateKey = true;
      keyFile = "/var/lib/sops-nix/key.txt";
    };
  };
}
