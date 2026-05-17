{ ... }:

let
  nginx' = {
    services.nginx = {
      enable = true;
      virtualHosts."localhost" = {
        default = true;
        locations."/" = {
          return = "200 'Hello from NixOS server'";
        };
      };
    };

    networking.firewall.allowedTCPPorts = [
      80
      443
    ];
  };

  ssh' = {
    services.ssh = {
      enable = true;
    };
  };
in
{
  imports = [
    nginx'
    ssh'
  ];
}
