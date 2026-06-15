{
  pkgs,
  lib,
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
         DATETIME="$(date -Is)"
         LOG_FILE="$HOME/$DATETIME.log"

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

    programs.zsh.loginShellInit = ''
      if [ -z "''${TMUX}" ] && [ -z "''${DISPLAY}" ] && [ -z "''${WAYLAND_DISPLAY}" ]; then
        exec tmux new-session -A -s main
      fi
    '';

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
        systemd-boot = {
          enable = true;
          editor = false;
          configurationLimit = 5;
        };
        timeout = 0;
      };

      kernelParams = [
        "quiet"
        "loglevel=3"
        "rd.systemd.show_status=false"
        "rd.udev.log_level=3"
        "systemd.show_status=auto"
        "nowatchdog"
      ];

      consoleLogLevel = 0;
      initrd.compressor = "zstd";
      initrd.systemd.enable = true;

      resumeDevice = lib.mkForce "";
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

    programs.git = {
      enable = true;
      config = {
        user.email = "waynevanson@gmail.com";
        user.name = "Wayne Van Son";
      };
    };

    environment.systemPackages = with pkgs; [
      networkmanager
      openssh
      brightnessctl
      optimize-boot
    ];

    systemd.services.NetworkManager-wait-online.enable = false;

    services.fstrim.enable = true;

    fileSystems."/".options = [ "noatime" ];

    programs.neovim = {
      enable = true;
      defaultEditor = true;
      viAlias = true;
      vimAlias = true;
      configure = {
        customRC = ''
          lua << EOF
          require("catppuccin").setup({
            flavour = "mocha",
          })
          vim.cmd.colorscheme("catppuccin")
          EOF

          let g:vimwiki_list = [{'path': '~/code/waynevanson/wiki', 'syntax': 'markdown', 'ext': 'md', 'path_html': '~/code/waynevanson/wiki/'}]
          let g:vimwiki_global_ext = 0
          set shm+=I
        '';
        packages.myplugins = with pkgs.vimPlugins; {
          start = [
            catppuccin-nvim
            vim-tmux-navigator
            vimwiki
          ];
        };
      };
    };

    programs.tmux = {
      enable = true;
      keyMode = "vi";
      plugins = with pkgs.tmuxPlugins; [
        catppuccin
        vim-tmux-navigator
      ];
      extraConfigBeforePlugins = ''
        run-shell 'tmux set -g @catppuccin_flavor "$(cat $HOME/.config/catppuccin-theme 2>/dev/null || echo mocha)"'
      '';
      extraConfig = ''
        # Move status bar to top from bottom
        set -g status-position top

        # Update status bar every second
        set -g status-interval 10

        # Show date, battery capacity
        set-window-option -g status-right "#(date +"%Y-%m-%d %R") #(cat /sys/class/power_supply/BAT0/capacity)% "

        bind -n F5 run-shell "sudo brightnessctl --quiet set 10%-"
        bind -n F6 run-shell "sudo brightnessctl --quiet set 10%+"

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
