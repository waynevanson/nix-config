{ config, ... }:

let
  sops' = {
    sops.secrets.spaceship-token = {
      sopsFile = ../../.sops.secrets.yaml;
      key = "spaceship/token";
    };
  };

  acme' = {
    security.acme = {
      acceptTerms = true;
      defaults.email = "waynevanson@gmail.com";
      certs."waynevanson.com" = {
        dnsProvider = "spaceship";
        webroot = null;
        credentialFiles = {
          "SPACESHIP_API_TOKEN_FILE" = config.sops.secrets.spaceship-token.path;
        };
      };
    };
  };

  nginx' = {
    services.nginx = {
      enable = true;
      virtualHosts."waynevanson.com" = {
        enableACME = true;
        forceSSL = true;
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

  host' = {
    networking.hostName = "server";

    boot.loader.grub = {
      enable = true;
      devices = [ "/dev/sda" ]; # TODO: change to actual disk
    };

    fileSystems."/" = {
      device = "/dev/sda1"; # TODO: change to actual root partition
      fsType = "ext4";
    };

    users.users.waynevanson = {
      isNormalUser = true;
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDVwuz7O5uHh6blzTrfETNz5omxutdgiPTrl+PKNcgSa waynevanson@nixos"
      ];
    };

    system.stateVersion = "26.05";
  };

  ssh' = {
    services.sshd = {
      enable = true;
    };
  };

in
{
  imports = [
    sops'
    acme'
    nginx'
    ssh'
    host'
  ];
}
