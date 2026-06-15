{
  programs.zsh = {
    enable = true;
    enableCompletion = true;

    initExtra = ''
      if [[ -z "$TMUX" && "$TTY" == /dev/tty* ]]; then
        exec tmux new-session -A -s main
      fi
    '';
  };
}
