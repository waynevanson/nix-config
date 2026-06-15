{
  pkgs,
  ...
}:
let

  catppuccinMocha = {
    palette = "custom";

    palette-black = "30,30,46";
    palette-red = "243,139,168";
    palette-green = "166,227,161";
    palette-yellow = "249,226,175";
    palette-blue = "137,180,250";
    palette-magenta = "245,194,231";
    palette-cyan = "148,226,213";
    palette-light-grey = "186,194,222";
    palette-dark-grey = "88,91,112";
    palette-light-red = "243,139,168";
    palette-light-green = "166,227,161";
    palette-light-yellow = "249,226,175";
    palette-light-blue = "137,180,250";
    palette-light-magenta = "245,194,231";
    palette-light-cyan = "148,226,213";
    palette-white = "166,173,200";

    palette-foreground = "205,214,244";
    palette-background = "30,30,46";
  };

  optimize-boot = pkgs.writeShellApplication {
    name = "optimize-boot";
    runtimeInputs = with pkgs; [
      coreutils
      git
      gnugrep
      gnused
      sudo
      systemd
      util-linux
    ];

    text = ''
      function main(){
         local DATETIME="$(date -Is)"
         local LOG_FILE="~/$DATETIME.log"

         function log() {
             echo "$@" | tee -a "$LOG_FILE" || true
         }

         systemd-analyze 2>&1 | tee -a "$LOG_FILE" || true
         systemd-analyze blame 2>&1 | head -20 | tee -a "$LOG_FILE" || true
         systemd-analyze critical-chain 2>&1 | tee -a "$LOG_FILE" || true
         dmesg 2>/dev/null | grep -iE "error|fail|timeout" | tee -a "$LOG_FILE" || true
      }

      main
    '';
  };

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

    boot = {
      kernelPackages = pkgs.linuxPackages_zen;

      loader = {
        efi.canTouchEfiVariables = true;
        systemd-boot.enable = true;
      };
    };

    services.getty.autologinUser = "waynevanson";
    services.getty.greetingLine = "";
    services.getty.helpLine = "";

    services.kmscon = {
      enable = true;
      config = {
        font-size = 24;
        font-name = "JetBrains Mono";
      }
      // catppuccinMocha;
    };

    fonts.packages = [
      pkgs.jetbrains-mono
    ];

    programs.git.enable = true;

    environment.systemPackages = with pkgs; [
      networkmanager
      openssh
      brightnessctl
      optimize-boot
    ];

    programs.neovim = {
      enable = true;
      defaultEditor = true;
      viAlias = true;
      vimAlias = true;
    };

    programs.tmux = {
      enable = true;
      keyMode = "vi";
      plugins = with pkgs.tmuxPlugins; [ catppuccin ];
      extraConfigBeforePlugins = ''
        run-shell 'tmux set -g @catppuccin_flavor "$(cat ~/.config/catppuccin-theme 2>/dev/null || echo mocha)"'
      '';
      extraConfig = ''
        # Move status bar to top from bottom
        set -g status-position top

        # # Show battery capacity
        # set-window-option -g status-right "#(cat /sys/class/power_supply/BAT0/capacity)%"

        # bind -n F5 run-shell "brightnessctl set -10%"
        # bind -n F6 run-shell "brightnessctl set +10%"

        # # Toggle light/dark theme using <prefix>,  K (CTRL + B, K)
        # # T is already time
        # bind -g K run-shell "toggle-catppuccin-theme"
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
