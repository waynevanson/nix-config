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
        extraDomainNames = [ "*.waynevanson.com" ];
        dnsProvider = "spaceship";
        webroot = null;

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
      virtualHosts = {
        "waynevanson.com" = {
          enableACME = true;
          forceSSL = true;
        };
        "attic.waynevanson.com" = {
          useACMEHost = "waynevanson.com";
          forceSSL = true;
        };
        "git.waynevanson.com" = {
          useACMEHost = "waynevanson.com";
          forceSSL = true;
          locations."/" = {
            proxyPass = "http://localhost:3000";
            proxyWebsockets = true;
            extraConfig = ''
              proxy_set_header Host $host;
              proxy_set_header X-Real-IP $remote_addr;
              proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
              proxy_set_header X-Forwarded-Proto $scheme;
            '';
          };
        };
      };
    };

    networking.firewall.allowedTCPPorts = [
      80
      443
    ];
  };

  forgejo' = {
    services.forgejo = {
      enable = true;
      database.type = "postgres";
      database.host = "localhost";
      database.port = 5432;
      database.name = "forgejo";
      database.user = "forgejo";
      database.passwordFile = config.sops.secrets.forgejo-db-pass.path;
      lfs.enable = true;
      settings = {
        server = {
          DOMAIN = "git.waynevanson.com";
          ROOT_URL = "https://git.waynevanson.com/";
          HTTP_PORT = 3000;
        };
        service = {
          DISABLE_REGISTRATION = true;
        };
      };
    };

    services.postgresql = {
      enable = true;
      ensureDatabases = [ "forgejo" ];
      ensureUsers = [
        {
          name = "forgejo";
          ensureDBOwnership = true;
        }
      ];
    };

    sops.secrets.forgejo-db-pass = {
      sopsFile = ../../.sops.secrets.yaml;
      key = "postgres/password";
    };
  };

  garage' = {
    services.garage = {
      enable = true;
      package = config.nixpkgs.pkgs.garage;
      settings = {
        data_dir = "/var/lib/garage";
        rpc_bind_addr = "[::]:3901";
        rpc_secret = "";
        s3_api = {
          api_bind_addr = "[::]:3900";
          s3_region = "garage";
        };
      };
    };

    services.nginx.virtualHosts."s3.waynevanson.com" = {
      useACMEHost = "waynevanson.com";
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://localhost:3900";
        extraConfig = ''
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
        '';
      };
    };
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
    forgejo'
    ssh'
    host'
    facter'
    garage'
    ./disko-configuration.nix
  ];
}
