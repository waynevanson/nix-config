{
  programs.nixvim.colorschemes.catppuccin = {
    enable = true;
    settings = {
      integrations = {
        gitsigns = true;
        treesitter = true;
        notify = true;
      };
    };
  };
}
