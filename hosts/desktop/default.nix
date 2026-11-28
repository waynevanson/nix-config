{
  config,
  pkgs,
  inputs,
  system,
  self,
  ...
}:
let
  hardware' = {
    hardware.facter.reportPath = ./facter.json;
  };
  custom' = {
    custom = {
      # virtualisation.docker.enable = true;
      virtualisation.containerd.enable = true;
      services = {
        attic-client.enable = false;
        cosmic.enable = false;
        gnome.enable = true;
      };
    };
  };
  # HP DeskJet 2700 series all-in-one, attached over USB as 03f0:1853.
  # HPLIP provides both the CUPS driver and the `hpaio` SANE backend for
  # this model; sane-airscan adds driverless eSCL/WSD support.
  #
  # The 2700 series scans through HPLIP's closed `bb_escl` plugin. With plain
  # `hplip` the device is detected but every scan fails in `hpaio` with
  # "Plugin version is not matching" (hplip.state/plugin absent from the
  # read-only store). `hplipWithPlugin` ships the plugin plus hplip.state.
  hplip = pkgs.hplipWithPlugin;
  printing' = {
    services = {
      printing = {
        enable = true;
        drivers = [ hplip ];
        # Advertise queues over mDNS/DNS-SD, and allow other machines to
        # print to them (TCP 631).
        browsing = true;
        openFirewall = true;
      };
      # Needed to discover network printers/scanners (and `.local` names).
      avahi = {
        enable = true;
        nssmdns4 = true;
        openFirewall = true;
      };
    };
    hardware.sane = {
      enable = true;
      extraBackends = [
        hplip
        pkgs.sane-airscan
      ];
    };
    environment.systemPackages = with pkgs; [
      # GNOME Document Scanner.
      simple-scan
      # CUPS/GNOME printer management GUI.
      system-config-printer
    ];
    # `scanner` for SANE (USB `uaccess` also covers local logins), `lpadmin`
    # to add/remove queues without sudo, `lp` to use them.
    users.users.waynevanson.extraGroups = [
      "lp"
      "lpadmin"
      "scanner"
    ];
  };
  # Home Manager configuration for both users
  homeManager' = {
    # Use global pkgs and enable user packages
    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      extraSpecialArgs = {
        inherit inputs system self;
      };
      # Configuration for regular user
      users.waynevanson =
        { self, lib, ... }:
        {
          imports = [ self.homeModules.waynevanson ];
          home = {
            username = "waynevanson";
            homeDirectory = "/home/waynevanson";
            stateVersion = "25.05";
          };
        };
    };
  };
  system' = {
    # todo: move this somewhere so it's consumed by everything
    # Set your time zone.
    time.timeZone = "Australia/Melbourne";
    # Closing the lid keeps the machine awake. All three are set explicitly
    # because the *ExternalPower*/*Docked* variants fall back to
    # HandleLidSwitch, but behaved as "suspend" when unset before systemd 256.
    services.logind.settings.Login = {
      HandleLidSwitch = "ignore";
      HandleLidSwitchExternalPower = "ignore";
      HandleLidSwitchDocked = "ignore";
    };
    # Select internationalisation properties.
    i18n = {
      # Select internationalisation properties.
      defaultLocale = "en_AU.UTF-8";
      extraLocaleSettings = {
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
    };
  };
  user' = {
    users = {
      defaultUserShell = pkgs.zsh;
      users.waynevanson = {
        isNormalUser = true;
        description = "Wayne Van Son";
        extraGroups = [
          "audio"
          "video"
          "networkmanager"
          "wheel"
        ];
      };
    };
    programs = {
      zsh.enable = true;
      nix-ld = {
        enable = true;
        # libraries = [];
      };
      steam.enable = true;
    };
  };
  host' = {
    system.stateVersion = "25.05";
    networking.hostName = "nixos"; # Define your hostname.
    boot.loader = {
      efi.canTouchEfiVariables = true;
      systemd-boot.enable = true;
    };
    sops = {
      age.keyFile = "/home/waynevanson/.config/sops/age/keys.txt";
    };
  };
in
{
  imports = [
    #./disk-configuration.nix
    ./hardware-configuration.nix
    # JuiceFS volume backed by the Garage S3 bucket (replaces the old
    # user-scoped rclone mount of the `files` bucket).
    ./juicefs.nix
    # Joins the self-hosted Headscale tailnet as node `nixos`.
    ./tailscale.nix
    ../../modules
    inputs.home-manager.nixosModules.default
    inputs.juicefs-nix.nixosModules.default
    self.nixosModules.sops
    hardware'
    printing'
    host'
    system'
    user'
    homeManager'
    custom'
  ];
}
