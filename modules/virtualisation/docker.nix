{
  config,
  lib,
  pkgs,
  ...
}: {
  options.waynevanson.virtualisation.docker.enable = lib.mkEnableOption {};

  config = lib.mkIf config.waynevanson.virtualisation.docker.enable {
    virtualisation.docker.enable = true;
    users.users.waynevanson.extraGroups = ["docker"];
    environment.systemPackages = with pkgs; [
      docker
      docker-compose
    ];
  };
}
