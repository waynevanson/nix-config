{ ... }:
{
  imports = [
    ./alacritty.nix
    ./direnv.nix
    ./firefox.nix
    ./git.nix
    ./oh-my-posh
    ./packages.nix
    ./pi-coding-agent
    # Mounts the garage `files` bucket at ~/mnt/files via programs.rclone.
    # Enable once the server host is up; the FUSE mount itself doesn't need it.
    ./rclone.nix
    ./sops.nix
    ./vim.nix
    ./zsh.nix
  ];
  programs.home-manager.enable = true;
  home.enableNixpkgsReleaseCheck = false;
}
