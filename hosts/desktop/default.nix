{
  pkgs,
  inputs,
  system,
  ...
}: let
  hardware' = {
    hardware.facter.reportPath = ./facter.json;
  };

  packages = with pkgs; [
    alejandra
    curl
    direnv
    discord
    ghidra
    # todo: modularise
    git
    gnutar
    nerd-fonts.jetbrains-mono
    nfs-utils
    nil
    inputs.opencode.packages.${system}.default
    openscad
    prusa-slicer
    runelite
    tuckr
    unzip
    wget
    vscode.fhs
    xz
    zed-editor
    zip
  ];

  waynevanson = {
    # virtualisation.docker.enable = true;
    virtualisation.containerd.enable = true;

    programs.zsh.enable = true;
    programs.bitwig.enable = true;
    programs.nixvim.enable = true;
    programs.tmux.enable = true;
    programs.direnv.enable = true;

    services.cosmic.enable = true;

    nix.enable = true;
  };

  # Home Manager configuration for both users
  homeManager = {
    # Use global pkgs and enable user packages
    home-manager.useGlobalPkgs = true;
    home-manager.useUserPackages = true;

    # Configuration for regular user
    home-manager.users.waynevanson = {pkgs, ...}: {
      home.username = "waynevanson";
      home.homeDirectory = "/home/waynevanson";
      home.stateVersion = "25.05";

      # Let Home Manager install and manage itself
      programs.home-manager.enable = true;

      # Alacritty with Catppuccin Mocha theme
      programs.alacritty = {
        enable = true;
        settings = {
          colors = {
            primary = {
              background = "#1e1e2e";
              foreground = "#cdd6f4";
              dim_foreground = "#7f849c";
              bright_foreground = "#cdd6f4";
            };

            cursor = {
              text = "#1e1e2e";
              cursor = "#f5e0dc";
            };

            vi_mode_cursor = {
              text = "#1e1e2e";
              cursor = "#b4befe";
            };

            search = {
              matches = {
                foreground = "#1e1e2e";
                background = "#a6adc8";
              };
              focused_match = {
                foreground = "#1e1e2e";
                background = "#a6e3a1";
              };
            };

            footer_bar = {
              foreground = "#1e1e2e";
              background = "#a6adc8";
            };

            hints = {
              start = {
                foreground = "#1e1e2e";
                background = "#f9e2af";
              };
              end = {
                foreground = "#1e1e2e";
                background = "#a6adc8";
              };
            };

            selection = {
              text = "#1e1e2e";
              background = "#f5e0dc";
            };

            normal = {
              black = "#45475a";
              red = "#f38ba8";
              green = "#a6e3a1";
              yellow = "#f9e2af";
              blue = "#89b4fa";
              magenta = "#f5c2e7";
              cyan = "#94e2d5";
              white = "#bac2de";
            };

            bright = {
              black = "#585b70";
              red = "#f38ba8";
              green = "#a6e3a1";
              yellow = "#f9e2af";
              blue = "#89b4fa";
              magenta = "#f5c2e7";
              cyan = "#94e2d5";
              white = "#a6adc8";
            };

            indexed_colors = [
              {
                index = 16;
                color = "#fab387";
              }
              {
                index = 17;
                color = "#f5e0dc";
              }
            ];
          };
        };
      };
    };
  };

  system' = {
    programs.firefox.enable = true;

    # todo: move this somewhere so it's consumed by everything
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
  };

  user' = {
    users.users.waynevanson = {
      isNormalUser = true;
      description = "Wayne Van Son";
      extraGroups = ["audio" "video" "networkmanager" "wheel"];
      inherit packages;
    };

    # mount /mnt/secondary to /home/waynevanson/code
    systemd.tmpfiles.settings = {
      "waynevanson-code" = {
        "/home/waynevanson/code".d = {
          type = "L";
          user = "waynevanson";
          group = "users";
          argument = "/mnt/secondary";
        };
      };
    };

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
  };

  host' = {
    system.stateVersion = "25.05";

    networking.hostName = "nixos"; # Define your hostname.

    boot.loader = {
      efi.canTouchEfiVariables = true;
      systemd-boot.enable = true;
    };
  };
in {
  imports = [
    #./disk-configuration.nix
    ./hardware-configuration.nix
    ../../modules
    hardware'
    host'
    system'
    user'
    homeManager
  ];

  inherit waynevanson;
  environment.systemPackages = packages;
}
