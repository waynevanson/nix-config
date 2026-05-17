{ config, ... }:

let
  acme' = {
    sops = {
      secrets = {
        spaceship-client-id = {
          sopsFile = ../../.sops.secrets.yaml;
          key = "spaceship/client-id";
        };

        spaceship-client-secret = {
          sopsFile = ../../.sops.secrets.yaml;
          key = "spaceship/client-secret";
        };
      };

      templates.spacetime-environment-file = {
        content = ''
          SPACESHIP_API_KEY=${config.sops.placeholder.spaceship-client-id}
          SPACESHIP_API_SECRET=${config.sops.placeholder.spaceship-client-secret}
        '';
        owner = "acme";
      };
    };

    security.acme = {
      acceptTerms = true;
      defaults.email = "waynevanson@gmail.com";
      certs."waynevanson.com" = {
        extraDomainNames = [
          "git.waynevanson.com"
          "atticd.waynevanson.com"
          "s3.garage.waynevanson.com"
          "web.garage.waynevanson.com"
        ];
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
      };
    };

    networking.firewall.allowedTCPPorts = [
      80
      443
    ];
  };

  # todo: allow self to create account and sign in
  forgejo' =
    { config, lib, ... }:
    {
      services.forgejo = {
        enable = true;
        database.type = "postgres";
        database.host = "localhost";
        database.port = 5432;
        database.name = "forgejo";
        database.user = "forgejo";
        # todo: this should probably be a file, but with a variable name or not?
        database.passwordFile = config.sops.secrets.forgejo-db-pass.path;
        lfs.enable = true;
        settings = {
          server = {
            DOMAIN = "git.waynevanson.com";
            ROOT_URL = "https://git.waynevanson.com/";
            HTTP_PORT = 3000;
            SSH_PORT = lib.head config.services.openssh.ports;
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

      services.nginx.virtualHosts."git.waynevanson.com" = {
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

  atticd' = {
    sops = {
      secrets.atticd-secret = {
        sopsFile = ../../.sops.secrets.yaml;
        key = "atticd/secret";
      };

      templates.atticd-environment-file = {
        content = ''
          ATTIC_SERVER_TOKEN_RS256_SECRET_BASE64=${config.sops.placeholder.atticd-secret}
        '';
        owner = config.services.atticd.user;
      };
    };

    users = {
      groups.atticd = { };
      users.atticd = {
        isSystemUser = true;
        group = "atticd";
      };
    };

    # todo: point to s3 garage on server
    services.atticd = {
      enable = true;
      environmentFile = config.sops.templates.atticd-environment-file.path;
      settings = {
        jwt = { };
        listen = "[::]:2884";
      };
    };

    services.nginx.virtualHosts."atticd.waynevanson.com" = {
      useACMEHost = "waynevanson.com";
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://localhost:2884";
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

  garage' = {
    sops.secrets.garage-rpc-secret = {
      sopsFile = ../../.sops.secrets.yaml;
      key = "garage/rpc-secret";
    };

    # todo: add
    services.garage = {
      enable = true;
      package = config.nixpkgs.pkgs.garage;
      settings = {
        replication_factor = 1;
        consistency_mode = "consistent";
        data_dir = "/var/lib/garage";
        rpc_bind_addr = "[::]:3901";
        # todo: use sops
        rpc_secret = "4425f5c26c5e11581d3223904324dcb5b5d5dfb14e5e7f35e38c595424f5f1e6";
        s3_api = {
          api_bind_addr = "[::]:3900";
          s3_region = "garage";
        };
        s3_web = {
          bind_addr = "[::]:3902";
          root_domain = ".web.garage.localhost";
        };
      };
    };

    services.nginx.virtualHosts = {
      "s3.garage.waynevanson.com" = {
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
      "web.garage.waynevanson.com" = {
        useACMEHost = "waynevanson.com";
        forceSSL = true;
        locations."/" = {
          proxyPass = "http://localhost:3902";
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

  host' = {
    networking.hostName = "server";

    boot.loader.grub = {
      # no need to set devices, disko will add all devices that have a EF02 partition to the list already
      # devices = [ ];
      efiSupport = true;
      efiInstallAsRemovable = true;
    };

    # Allows use of `--sudo` without a password when running `nixos-rebuild switch`
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
    atticd'
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
