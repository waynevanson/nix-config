{ pkgs, ... }:

{
  # The nix-minecraft module creates the minecraft user/group automatically.
  # Ensure the admin user can manage files and attach to the console.
  users.users.waynevanson.extraGroups = [ "minecraft" ];

  services.minecraft-servers = {
    enable = true;
    eula = true;
    group = "minecraft";
    servers.main = {
      enable = true;
      autoStart = true;
      restart = "always";
      openFirewall = true;
      enableReload = true;
      # Matches the version of the imported world (paper-1.21.7-17.jar).
      # Can be upgraded after the world is confirmed working.
      package = pkgs.paperServers.paper-1_21_7-build_17;
      jvmOpts = "-Xmx8192M";
      serverProperties = {
        server-port = 25565;
        gamemode = 0;
        difficulty = 3;
        max-players = 20;
        motd = "Hugh G. Wang";
        "white-list" = false;
        "online-mode" = true;
      };
      operators = {
      };
    };
  };
}
