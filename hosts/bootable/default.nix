{
  lib,
  modulesPath,
  ...
}:
{
  imports = [
    "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix"
    "${modulesPath}/installer/cd-dvd/channel.nix"
  ];

  # nixos-anywhere connects to this machine as root over SSH.
  # SSH password login is disabled; only the authorized key below can log in.
  # The console still allows passwordless root login, like the stock installer.
  users.users.root = {
    initialHashedPassword = lib.mkForce "";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDVwuz7O5uHh6blzTrfETNz5omxutdgiPTrl+PKNcgSa waynevanson@nixos"
    ];
  };

  boot.zfs.forceImportRoot = false;

  services.openssh = {
    enable = true;
    settings.PermitRootLogin = lib.mkForce "prohibit-password";
  };
}
