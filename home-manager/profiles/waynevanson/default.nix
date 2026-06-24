{ ... }:
{
  imports = [
    ./alacritty.nix
    ./direnv.nix
    ./firefox.nix
    ./git.nix
    ./oh-my-posh
    ./packages.nix
    ./pi-coding-agent.nix
    ./sops.nix
    ./vim.nix
    ./zsh.nix
  ];
  programs.home-manager.enable = true;
}
