{
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];

    substituters = [
      "https://atticd.waynevanson.com/default"
      "https://nix-community.cachix.org"
      "https://cache.nixos.org/"
    ];

    trusted-public-keys = [
      "default:pS97iTPm4yOtVXO7lpAINY+vJB5tTEJqAmPJQPWajr0="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];

    trusted-users = [
      "@wheel"
      "waynevanson"
    ];
  };
}
