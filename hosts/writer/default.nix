{
  pkgs,
  inputs,
  system,
  ...
}:
let

  system' = {
    time.timeZone = "Australia/Melbourne";

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
    users.defaultUserShell = pkgs.zsh;
    programs.zsh.enable = true;

    users.users.waynevanson = {
      isNormalUser = true;
      description = "Wayne Van Son";
      extraGroups = [
        "networkmanager"
        "wheel"
      ];
    };

    security.sudo.wheelNeedsPassword = false;
  };

  nix' = {
    nix.settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];

      substituters = [
        "https://nix-community.cachix.org"
      ];

      trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];

      trusted-users = [
        "@wheel"
        "waynevanson"
      ];
    };
  };

  host' = {
    system.stateVersion = "26.05";

    networking.hostName = "writer";
    networking.networkmanager.enable = true;

    boot.loader = {
      efi.canTouchEfiVariables = true;
      systemd-boot.enable = true;
    };

    hardware.facter.reportPath = ./facter.json;

    services.getty.autologinUser = "waynevanson";

    services.kmscon = {
      enable = true;
      config = {
        font-name = "JetBrains Mono";
      };
    };

    fonts.packages = [
      pkgs.jetbrains-mono
    ];

    programs.git.enable = true;

    environment.systemPackages = with pkgs; [
      networkmanager
      openssh
    ];

    programs.neovim = {
      enable = true;
      defaultEditor = true;
      viAlias = true;
      vimAlias = true;
      configure = {
        luaRcContent = ''
          require("catppuccin").setup({
            flavour = "mocha",
          })
          vim.cmd.colorscheme("catppuccin")
        '';
        packages.myPlugins = with pkgs.vimPlugins; {
          start = [ catppuccin-nvim ];
        };
      };
    };

    programs.tmux = {
      enable = true;
      keyMode = "vi";
      plugins = with pkgs.tmuxPlugins; [ catppuccin ];
      extraConfig = ''
        set -g @catppuccin_flavor "mocha"
      '';
    };
  };
in
{
  imports = [
    ./disko-configuration.nix
    ../../modules
    host'
    nix'
    system'
    user'
  ];
}
