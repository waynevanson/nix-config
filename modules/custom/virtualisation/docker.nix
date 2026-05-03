{
  config,
  lib,
  pkgs,
  ...
}: {
  options.custom.virtualisation.docker.enable = lib.mkEnableOption {};

  config = lib.mkIf config.custom.virtualisation.docker.enable {
    virtualisation.docker.enable = true;
    users.users.waynevanson.extraGroups = ["docker"];
    environment.systemPackages = with pkgs; [
      docker
      docker-compose
    ];
  };
}
