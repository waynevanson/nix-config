# Apply per user via `home-manager.users.waynevanson`
{...}: {
  home = {
    imports = [
      ./alacritty
    ];

    programs.home-manager.enable = true;

    username = "waynevanson";
    homeDirectory = "/home/waynevanson";
    stateVersion = "25.05";
  };
}
