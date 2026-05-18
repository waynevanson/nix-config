let
  secrets' = {
    sops.defaultSopsFile = ../../.sops.secrets.yaml;
    sops.secrets = {
      spaceship-client-id.key = "spaceship/client-id";
      spaceship-client-secret.key = "spaceship/client-secret";
      atticd-secret.key = "atticd/secret";
      garage-rpc-secret.key = "garage/rpc-secret";
      garage-access-key.key = "garage/access-key";
      garage-secret-key.key = "garage/secret-key";
      postgres-password.key = "postgres/password";
    };
  };
  acme' =
    { config, ... }:
    {
      security.acme = {
        acceptTerms = true;
        defaults.email = "waynevanson@gmail.com";
        certs."waynevanson.com" = {
          extraDomainNames = [
            "git.waynevanson.com"
            "atticd.waynevanson.com"
            # todo: does this serve the default bucket?
            "s3.garage.waynevanson.com"
            # todo: <bucket>.s3.garage.waynevanson.com
            "*.s3.garage.waynevanson.com"
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
        database.passwordFile = config.sops.secrets.postgres-password.path;
        lfs.enable = true;
        settings = {
          server = {
            DOMAIN = "git.waynevanson.com";
            ROOT_URL = "https://git.waynevanson.com/";
            HTTP_PORT = 3098;
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

      services.nginx.virtualHosts."git.waynevanson.com" = {
        useACMEHost = "waynevanson.com";
        forceSSL = true;
        locations."/" = {
          proxyPass = "http://localhost:3098";
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

  atticd' =
    { config, ... }:
    {
      sops.templates.atticd-environment-file = {
        content = ''
          ATTIC_SERVER_TOKEN_RS256_SECRET_BASE64=${config.sops.placeholder.atticd-secret}
        '';
        owner = "atticd";
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

  # todo: expose the other ports so it can be used by clients?
  # todo: make accessible for s5cmd
  garage' =
    { config, lib, ... }:
    {
      sops.templates.garage-environment-file = {
        content = ''
          GARAGE_RPC_SECRET=${config.sops.placeholder.garage-rpc-secret}
          GARAGE_DEFAULT_ACCESS_KEY=${config.sops.placeholder.garage-access-key}
          GARAGE_DEFAULT_SECRET_KEY=${config.sops.placeholder.garage-secret-key}
          GARAGE_DEFAULT_BUCKET="default-bucket"
        '';
        owner = "garage";
      };

      users = {
        users.garage = {
          isSystemUser = true;
          group = "garage";
        };
        groups.garage = { };
      };

      services.garage = {
        enable = true;
        package = config.nixpkgs.pkgs.garage_2;
        environmentFile = config.sops.templates.garage-environment-file.path;
        settings = {
          replication_factor = 1;
          consistency_mode = "consistent";
          data_dir = "/var/lib/garage";
          rpc_bind_addr = "[::]:3901";
          s3_api = {
            api_bind_addr = "[::]:3900";
            s3_region = "garage";
          };
        };

      };

      systemd.services.garage.serviceConfig = {
        # Garage needs to have a known user to read the secrets
        DynamicUser = lib.mkForce false;
        ExecStart = lib.mkForce "${config.services.garage.package}/bin/garage server --single-node --default-bucket";
      };

      services.nginx.virtualHosts."s3.garage.waynevanson.com" = {
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

    # Set your time zone.
    time.timeZone = "Australia/Melbourne";

    # Select internationalisation properties.
    i18n.defaultLocale = "en_AU.UTF-8";

    i18n.extraLocaleSettings = {
      LC_ADDRESS = "en_AU.UTF-8";
      LC_IDENTIFICATION = "en_AU.UTF-8";
      LC_MEASUREMENT = "en_AU.UTF-8";
      LC_MONETARY = "en_AU.UTF-8";
      LC_NAME = "en_AU.UTF-8";
      LC_NUMERIC = "en_AU.UTF-8";
      LC_PAPER = "en_AU.UTF-8";
      LC_TELEPHONE = "en_AU.UTF-8";
      LC_TIME = "en_AU.UTF-8";
    };
    sops.defaultSopsFile = ../../.sops.secrets.yaml;
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
    (
      { self, ... }:
      {
        imports = [ self.nixosModules.sops ];
      }
    )
    atticd'
    garage'
    acme'
    nginx'
    forgejo'
    ssh'
    host'
    facter'
    # secrets'
    ./disko-configuration.nix
  ];
}
