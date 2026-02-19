{pkgs, ...}: {
  programs.tmux = {
    enable = true;
    baseIndex = 1;
    newSession = true;
    escapeTime = 0;
    historyLimit = 50000;
    customPaneNavigationAndResize = true;
    keyMode = "vi";

    plugins = with pkgs.tmuxPlugins; [
      better-mouse-mode
      vim-tmux-navigator
      catppuccin
    ];

    extraConfigBeforePlugins = ''
      # Enable true color for terminals, otherwise neovim colors don't work.
      set -ga terminal-overrides 'screen:Tc'

      # Split panes into current work directory, rather than home.
      bind '"' split-window -v -c "#{pane_current_path}"
      bind '%' split-window -h -c "#{pane_current_path}"
    '';
  };
}
