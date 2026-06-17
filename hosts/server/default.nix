let
  acme' =
    { config, ... }:
    {
      security.acme = {
        acceptTerms = true;
        defaults.email = "waynevanson@gmail.com";
        certs."waynevanson.com" = {
          extraDomainNames = [
            "git.waynevanson.com"
            "runner.git.waynevanson.com"
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

  # nix binary cache server
  atticd' =
    { config, ... }:
    let
      port = "2884";
    in
    {
      sops.templates.atticd-environment-file = {
        content = ''
          ATTIC_SERVER_TOKEN_RS256_SECRET_BASE64=${config.sops.placeholder.atticd-secret}
          AWS_ACCESS_KEY_ID=${config.sops.placeholder.garage-access-key}
          AWS_SECRET_ACCESS_KEY=${config.sops.placeholder.garage-secret-key}
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

      services.atticd = {
        enable = true;
        environmentFile = config.sops.templates.atticd-environment-file.path;
        settings = {
          jwt = { };
          listen = "[::]:${port}";
          storage = {
            type = "s3";
            region = "garage";
            bucket = "default-bucket";
            endpoint = "https://s3.garage.waynevanson.com";
          };
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
    let
      group = "garage";
      port = {
        s3 = "3900";
        rpc = "3901";
      };
    in
    {
      sops.templates.garage-environment-file = {
        content = ''
          GARAGE_RPC_SECRET=${config.sops.placeholder.garage-rpc-secret}
          GARAGE_DEFAULT_ACCESS_KEY=${config.sops.placeholder.garage-access-key}
          GARAGE_DEFAULT_SECRET_KEY=${config.sops.placeholder.garage-secret-key}
          GARAGE_DEFAULT_BUCKET="default-bucket"
        '';
        owner = group;
      };

      users.groups.${group} = { };
      users.users.${group} = {
        isSystemUser = true;
        group = group;
      };

      services.garage = {
        enable = true;
        package = config.nixpkgs.pkgs.garage_2;
        environmentFile = config.sops.templates.garage-environment-file.path;
        settings = {
          replication_factor = 1;
          consistency_mode = "consistent";
          data_dir = "/var/lib/garage";
          rpc_bind_addr = "[::]:${port.rpc}";
          s3_api = {
            api_bind_addr = "[::]:${port.s3}";
            s3_region = "garage";
          };
        };

      };

      systemd.services.garage.serviceConfig = {
        # Override binary since we're using garage@^2
        ExecStart = lib.mkForce "${config.services.garage.package}/bin/garage server --single-node --default-bucket";

        DynamicUser = lib.mkForce false;
      };

      services.nginx.virtualHosts."s3.garage.waynevanson.com" = {
        useACMEHost = "waynevanson.com";
        forceSSL = true;
        locations."/" = {
          proxyPass = "http://localhost:${port.s3}";
          extraConfig = ''
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;

            # https://garagehq.deuxfleurs.fr/documentation/cookbook/reverse-proxy/#exposing-the-s3-endpoints
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_max_temp_file_size 0;
          '';
        };
      };
    };

  host' =
    { self, ... }:
    {

      imports = [ self.nixosModules.sops ];

      networking.hostName = "server";

      networking.extraHosts = ''
        127.0.0.1 git.waynevanson.com
      '';

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

      sops = {
        defaultSopsFile = ../../.sops.secrets.yaml;
        age.sshKeyPaths = [
          "/etc/ssh/ssh_host_ed25519_key"
        ];
      };

      services.sshd.enable = true;
    };
in
{
  imports = [
    ./forgejo.nix
    # ./forgejo-runner.nix
    atticd'
    garage'
    acme'
    nginx'
    host'
    ./disko-configuration.nix
  ];
}
