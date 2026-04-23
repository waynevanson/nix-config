{
  pkgs,
  inputs,
  system,
  ...
}:
{
  imports = [
    ./alacritty.nix
    ./direnv.nix
    ./oh-my-posh
    ./opencode
    ./tmux.nix
    ./zsh.nix
  ];

  home.packages = with pkgs; [
    curl
    discord
    # todo: modularise
    git
    gnutar
    nerd-fonts.jetbrains-mono
    nil
    nixd
    openscad
    prusa-slicer
    unzip
    wget
    xz
    zed-editor.fhs
    zip
    claude-code
    opencode
    inputs.self.packages.${system}.bitwig
    inputs.self.packages.${system}.pi-coding-agent
    inputs.meridian.packages.${system}.meridian
  ];

  programs.firefox.enable = true;
}
