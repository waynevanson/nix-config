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

  forgejo-runner' =
    { pkgs, config, ... }:
    let
      usergroup = "gitea-runner";
      tokenName = "forgejo-runner-token";
      tokenFileName = "forgejo-runner-token-file";
    in
    {

      sops = {
        secrets.${tokenName}.key = "forgejo/token";
        templates.${tokenFileName} = {
          content = ''
            TOKEN="${config.sops.placeholder.${tokenName}}"
          '';
          owner = usergroup;
        };
      };

      # https://github.com/NixOS/nixpkgs/blob/nixos-unstable/nixos/modules/services/continuous-integration/gitea-actions-runner.nix
      services.gitea-actions-runner = {
        package = pkgs.forgejo-runner;
        instances.default = {
          enable = true;
          name = "default";
          url = "https://git.waynevanson.com";
          labels = [
            "nixos:docker://nixos/nix@sha256:72a13b0f42e3cc515945aa4250b772381d93c96d4bf93aa950b5c68defdab1dd"
          ];
          tokenFile = config.sops.templates.${tokenFileName}.path;
        };
      };

      # it's hanging here for reasons unknown due to virtualisation
      systemd.user.services.dbus-broker.restartIfChanged = false;

      users = {
        groups.${usergroup} = { };
        users.${usergroup} = {
          isSystemUser = true;
          group = usergroup;
        };
      };

      virtualisation.podman.enable = true;
    };

  # nix binary cache server
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
      hardware.facter.reportPath = ./facter.json;
    };
in
{
  imports = [
    ./forgejo.nix
    # atticd'
    # garage'
    acme'
    nginx'
    host'
    forgejo-runner'
    ./disko-configuration.nix
  ];
}
