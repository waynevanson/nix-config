{
  lib,
  modulesPath,
  ...
}: {
  imports = [
    "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix"
  ];

  # Needed for https://github.com/NixOS/nixpkgs/issues/58959
  boot.supportedFilesystems = lib.mkForce ["btrfs" "reiserfs" "vfat" "f2fs" "xfs" "ntfs" "cifs"];

  services.openssh = {
    enable = true;
    banner = ''
      Welcome to the bootable image.

      You better be installing NixOS via remote.

      Failure to do so will send you to the ram ranch.
    '';

    settings = {
      PermitRootLogin = "yes";
    };
  };

  # a tequila
  users.users.root.hashedPassword = "$6$HekR9ieGsg7Y5WKq$fjltga7g9Q4mL.oxnNjw2UvOAJvYVljiCGg1j4Ka70buJ37tsCtxpYj5V4pyu0SfGYIjJq9EaNXFPHP259AKF0";
}
