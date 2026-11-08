{
  lib,
  modulesPath,
  ...
}:
let
  adminKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDVwuz7O5uHh6blzTrfETNz5omxutdgiPTrl+PKNcgSa waynevanson@nixos";
in
{
  imports = [
    "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix"
    "${modulesPath}/installer/cd-dvd/channel.nix"
  ];

  # nixos-anywhere can connect as root or as waynevanson; both use the same
  # key. The console still allows passwordless root login, like the stock
  # installer.
  users.users.root = {
    initialHashedPassword = lib.mkForce "";
    openssh.authorizedKeys.keys = [ adminKey ];
  };

  # Use the same non-root nixos-anywhere flow as the running server.
  security.sudo.wheelNeedsPassword = false;
  users.users.waynevanson = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [ adminKey ];
  };

  boot.zfs.forceImportRoot = false;

  services.openssh = {
    enable = true;
    settings.PermitRootLogin = lib.mkForce "prohibit-password";
  };
}
