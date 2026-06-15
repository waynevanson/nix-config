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

  themeFile = "$HOME/.config/catppuccin-theme";

  toggleThemeScript = pkgs.writeShellScriptBin "toggle-catppuccin-theme" ''
    THEME_FILE="${themeFile}"
    mkdir -p "$(dirname "$THEME_FILE")"

    CURRENT=$(cat "$THEME_FILE" 2>/dev/null || echo "mocha")
    if [ "$CURRENT" = "mocha" ]; then
      NEXT="latte"
    else
      NEXT="mocha"
    fi
    echo "$NEXT" > "$THEME_FILE"

    if [ -n "$TMUX" ]; then
      tmux set-option -g @catppuccin_flavor "$NEXT"
      tmux source-file /etc/tmux.conf
    fi

    for socket in /tmp/nvim-*; do
      if [ -S "$socket" ]; then
        ${pkgs.neovim}/bin/nvim --server "$socket" --remote-send ':lua _G.apply_catppuccin_theme("'$NEXT'")<CR>' 2>/dev/null || true
      fi
    done
  '';

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

    services.getty.autologinUser = "waynevanson";

    services.kmscon = {
      enable = true;
      config = {
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
      toggleThemeScript
    ];

    programs.neovim = {
      enable = true;
      defaultEditor = true;
      viAlias = true;
      vimAlias = true;
    };

    environment.etc."xdg/nvim/sysinit.lua".text = ''
      local theme_file = vim.fn.expand("${themeFile}")

      local function read_theme()
        local f = io.open(theme_file, "r")
        if f then
          local theme = f:read("*l")
          f:close()
          return theme and theme:gsub("%s+", "") or "mocha"
        end
        return "mocha"
      end

      local function write_theme(theme)
        local f = io.open(theme_file, "w")
        if f then
          f:write(theme)
          f:close()
        end
      end

      function _G.apply_catppuccin_theme(theme)
        require("catppuccin").setup({ flavour = theme })
        vim.cmd.colorscheme("catppuccin")
      end

      local function update_tmux(theme)
        if vim.env.TMUX then
          vim.fn.system('tmux set-option -g @catppuccin_flavor "' .. theme .. '"')
          vim.fn.system("tmux source-file /etc/tmux.conf")
        end
      end

      local function broadcast_theme(theme)
        local sockets = vim.fn.glob("/tmp/nvim-*", false, true)
        local self_socket = vim.v.servername
        for _, socket in ipairs(sockets) do
          if socket ~= self_socket then
            local cmd = string.format(
              "nvim --server %s --remote-send %s 2>/dev/null",
              vim.fn.shellescape(socket),
              vim.fn.shellescape(':lua _G.apply_catppuccin_theme("' .. theme .. '")<CR>')
            )
            vim.fn.system(cmd)
          end
        end
      end

      local function toggle_catppuccin_theme()
        local current = read_theme()
        local next_theme = current == "mocha" and "latte" or "mocha"
        write_theme(next_theme)
        update_tmux(next_theme)
        broadcast_theme(next_theme)
        _G.apply_catppuccin_theme(next_theme)
      end

      _G.apply_catppuccin_theme(read_theme())
      vim.fn.serverstart("/tmp/nvim-" .. vim.fn.getpid())
      vim.api.nvim_create_user_command("ToggleCatppuccin", toggle_catppuccin_theme, {})
    '';

    environment.etc."xdg/nvim/pack/nix/start/catppuccin-nvim".source = pkgs.vimPlugins.catppuccin-nvim;

    programs.tmux = {
      enable = true;
      keyMode = "vi";
      plugins = with pkgs.tmuxPlugins; [ catppuccin ];
      extraConfigBeforePlugins = ''
        run-shell 'tmux set -g @catppuccin_flavor "$(cat ~/.config/catppuccin-theme 2>/dev/null || echo mocha)"'
      '';
      extraConfig = ''
        bind T run-shell "toggle-catppuccin-theme"
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
