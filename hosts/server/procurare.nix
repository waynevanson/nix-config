{ pkgs, ... }:
{
  containers.procurare = {
    autoStart = true;
    privateNetwork = true;
    hostAddress = "10.233.1.1";
    localAddress = "10.233.1.2";
    config = {
      pkgs,
      ...
    }:
    {
      system.stateVersion = "26.05";

      networking.firewall.allowedTCPPorts = [ 80 ];

      services.nginx = {
        enable = true;
        virtualHosts."procurare" = {
          default = true;
          root = pkgs.writeTextDir "index.html" "";
          locations."/" = {
            index = "index.html";
          };
        };
      };
    };
  };
}
