{
  config,
  lib,
  ...
}: {
  options = {
    homelab.user = lib.mkOption {
      type = lib.types.str;
      description = "User used for logging in";
    };
  };
  config = {
    users.users.${config.homelab.user} = {
      isNormalUser = true;
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDVwuz7O5uHh6blzTrfETNz5omxutdgiPTrl+PKNcgSa waynevanson@nixos"
      ];
      extraGroups = [
        "wheel"
        "networkmanager"
        "video"
        "render"
      ];
    };
  };
}
