{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    initContent = ''
      if [[ -z "$TMUX" && "$TTY" == /dev/tty* ]]; then
        exec tmux new-session -A -s main
      fi
    '';
  };
}
