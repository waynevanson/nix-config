{
  pkgs,
  inputs,
  system,
  config,
  ...
}:
{
  imports = [
    inputs.sops-nix.homeManagerModules.sops
    ../../modules/alacritty.nix
    ../../modules/direnv.nix
    ../../modules/oh-my-posh
    ../../modules/pi-coding-agent.nix
    ./opencode
    ../../modules/tmux.nix
    ../../modules/zsh.nix
  ];

  sops = {
    defaultSopsFile = ../../../.sops.secrets.yaml;
    age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
  };

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
    lunar-client
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
