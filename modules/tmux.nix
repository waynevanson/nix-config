{ pkgs, ... }:
{
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
      # Enable extended keys for applications like Neovim
      set -g extended-keys on
      set -g extended-keys-format csi-u
      set -sag terminal-features 'xterm*:extkeys'

      # Move status bar to top from bottom
      set -g status-position top

      # Update status bar every second
      set -g status-interval 10

      # Show date, battery capacity
      set-window-option -g status-right "#(date +'%Y-%m-%d %H:%M') #(cat /sys/class/power_supply/BAT0/capacity)% "

      # Adjust brightness with smaller steps near 0%
      bind -n F5 run-shell "brightnessctl --exponent=8 --quiet set 5%-"
      bind -n F6 run-shell "brightnessctl --exponent=8 --quiet set 5%+"
    '';
  };
}
