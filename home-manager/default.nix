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
    attic-client
    inputs.self.packages.${system}.bitwig
    curl
    discord
    fd
    fzf
    # todo: modularise
    git
    gnutar
    nerd-fonts.jetbrains-mono
    nil
    nixd
    openscad
    opencode
    openssl
    prusa-slicer
    ripgrep
    s5cmd
    unzip
    wget
    xz
    zed-editor.fhs
    zip
  ];

  programs = {
    firefox.enable = true;
    home-manager.enable = true;
    vim.enable = true;
    vim.defaultEditor = true;
  };
}
