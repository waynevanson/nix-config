{
  config,
  pkgs,
  ...
}: {
  programs.firefox.enable = true;
  programs.direnv = {
    enable = true;
    silent = true;
  };
}
