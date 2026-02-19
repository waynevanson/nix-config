{
  config,
  lib,
  ...
}: {
  options.waynevanson.nix.enable = lib.mkEnable {};

  config = lib.mkIf config.waynevanson.nix.enable {
    nix.settings = {
      # enable flakes
      experimental-features = ["nix-command" "flakes"];

      # enable cachix caches
      substituters = [
        "https://nix-community.cachix.org"
      ];
      trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
    };
  };
}
