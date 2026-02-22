{
  lib,
  modulesPath,
  ...
}: {
  imports = [
    "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix"
    "${modulesPath}/installer/cd-dvd/channel.nix"
  ];

  # Enable SSH in boot process
  # systemd.services.sshd.wantedBy = pkgs.lib.mkForce ["multi-user.target"];
  users.users.root = {
    initialHashedPassword = lib.mkForce "$6$lKZGI7BR6kyYGkzp$quldxyW3L0.CaA5b0j21tLglVlmhnSFIiQnuOZQi9s5iS1ImTeK5SlB3RUJk0BdDI9r4MdWNk7tBbRiJyydTY0";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDVwuz7O5uHh6blzTrfETNz5omxutdgiPTrl+PKNcgSa waynevanson@nixos"
    ];
  };

  services.openssh = {
    enable = true;
  };
}
