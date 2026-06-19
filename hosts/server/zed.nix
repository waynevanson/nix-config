{ ... }:
{
  networking.extraHosts = ''
    127.0.0.1 zed.waynevanson.com
  '';

  users.groups = {
    zed = { };
    developers = {
      members = [
        "waynevanson"
        "zed"
      ];
    };
  };

  users.users.zed = {
    isNormalUser = true;
    group = "zed";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDVwuz7O5uHh6blzTrfETNz5omxutdgiPTrl+PKNcgSa waynevanson@nixos"
    ];
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/zed 0755 zed zed -"
    "d /srv/code 2770 waynevanson developers -"
  ];

  programs.nix-ld.enable = true;
}
