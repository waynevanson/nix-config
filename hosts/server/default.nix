{ config, ... }:

let
  sops' = {
    sops.secrets.spaceship-client-id = {
      sopsFile = ../../.sops.secrets.yaml;
      key = "spaceship/client-id";
    };

    sops.secrets.spaceship-client-secret = {
      sopsFile = ../../.sops.secrets.yaml;
      key = "spaceship/client-secret";
    };

    sops.templates.spacetime-environment-file = {
      content = ''
        SPACESHIP_API_KEY=${config.sops.placeholder.spaceship-client-id}
        SPACESHIP_API_SECRET=${config.sops.placeholder.spaceship-client-secret}
      '';
      owner = "acme";
    };
  };

  acme' = {
    security.acme = {
      acceptTerms = true;
      defaults.email = "waynevanson@gmail.com";
      certs."waynevanson.com" = {
        dnsProvider = "spaceship";
        webroot = null;
        # todo: rotate because Gwen leaked
        credentialFiles = {
          "SPACESHIP_API_KEY_FILE" = config.sops.secrets.spaceship-client-id.path;
          "SPACESHIP_API_SECRET_FILE" = config.sops.secrets.spaceship-client-secret.path;
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
      # no need to set devices, disko will add all devices that have a EF02 partition to the list already
      # devices = [ ];
      efiSupport = true;
      efiInstallAsRemovable = true;

    };

    security.sudo.wheelNeedsPassword = false;

    users.users.waynevanson = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
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

  facter' = {
    hardware.facter.reportPath = ./facter.json;
  };

in
{
  imports = [
    sops'
    acme'
    nginx'
    ssh'
    host'
    facter'
    ./disko-configuration.nix
  ];
}
