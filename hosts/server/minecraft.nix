{ config, pkgs, ... }:

{
  # The nix-minecraft module creates the minecraft user/group automatically.
  # Ensure the admin user can manage files and attach to the console.
  users.users.waynevanson.extraGroups = [ "minecraft" ];

  sops.secrets.minecraft-rcon-password = {
    key = "minecraft/rcon-password";
    owner = "minecraft";
  };

  sops.templates.minecraft-environment-file = {
    content = ''
      RCON_PASSWORD=${config.sops.placeholder.minecraft-rcon-password}
    '';
    owner = "minecraft";
  };

  services.minecraft-servers = {
    enable = true;
    eula = true;
    group = "minecraft";
    environmentFile = config.sops.templates.minecraft-environment-file.path;

    servers.main = {
      enable = true;
      autoStart = true;
      restart = "always";
      openFirewall = true;
      enableReload = true;

      package = pkgs.paperServers.paper-1_21_11;
      jvmOpts = "-Xmx8192M";

      serverProperties = {
        server-port = 25565;
        gamemode = 0;
        difficulty = 3;
        max-players = 20;
        motd = "Waynevanson Minecraft Server";
        "white-list" = true;
        "online-mode" = true;
        "enable-rcon" = true;
        "rcon.port" = 25575;
        "rcon.password" = "@RCON_PASSWORD@";
        "broadcast-rcon-to-ops" = false;
      };

      whitelist = { };
      operators = { };
    };
  };
}
