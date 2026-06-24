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
  system' = {
    time.timeZone = "Australia/Melbourne";
    i18n = {
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
          "networkmanager"
          "video"
          "wheel"
        ];
      };
    };
    programs = {
      zsh = {
        enable = true;
        shellAliases = {
          wiki = "nvim +VimwikiIndex";
        };
        loginShellInit = ''
          if [ -z "''${TMUX}" ] && [ -z "''${DISPLAY}" ] && [ -z "''${WAYLAND_DISPLAY}" ]; then
            exec tmux new-session -A -s main
          fi
        '';
      };
    };
    security.sudo.wheelNeedsPassword = false;
  };
  host' = {
    system.stateVersion = "26.05";
    networking = {
      hostName = "writer";
      networkmanager.enable = true;
    };
    boot = {
      kernelPackages = pkgs.linuxPackages_zen;
      loader = {
        efi.canTouchEfiVariables = true;
        systemd-boot = {
          enable = true;
          editor = false;
        };
        timeout = 0;
      };
      initrd = {
        compressor = "zstd";
        systemd.enable = true;
      };
    };
    services = {
      getty = {
        autologinUser = "waynevanson";
        greetingLine = "";
        helpLine = "";
      };
      kmscon = {
        enable = true;
        config = {
          font-size = 24;
          font-name = "JetBrains Mono";
        }
        // catppuccinMocha;
      };
      udev.packages = [ pkgs.brightnessctl ];
      fstrim.enable = true;
    };
    fonts.packages = [
      pkgs.jetbrains-mono
    ];
    programs = {
      git = {
        enable = true;
        config = {
          user = {
            email = "waynevanson@gmail.com";
            name = "Wayne Van Son";
          };
        };
      };
      neovim = {
        enable = true;
        defaultEditor = true;
        viAlias = true;
        vimAlias = true;
        configure = {
          customRC =
            let
              lua = ''
                require("catppuccin").setup({
                  flavour = "mocha",
                })
                vim.cmd.colorscheme("catppuccin")
              '';
              vim = ''
                let g:vimwiki_list = [{'path': '~/code/waynevanson/wiki', 'syntax': 'markdown', 'ext': 'md', 'path_html': '~/code/waynevanson/wiki/'}]
                let g:vimwiki_global_ext = 0
                set shm+=I
              '';
            in
            ''
              lua << EOF
                ${lua}
              EOF

              ${vim}
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
    };
    environment.systemPackages = with pkgs; [
      networkmanager
      openssh
      brightnessctl
    ];
    systemd.services.NetworkManager-wait-online.enable = false;
    fileSystems."/".options = [ "noatime" ];
  };
in
{
  imports = [
    ./disko-configuration.nix
    ../../modules
    host'
    system'
    user'
  ];
}
