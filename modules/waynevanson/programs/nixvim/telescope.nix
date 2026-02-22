{pkgs, ...}: {
  programs.nixvim = {
    plugins = {
      telescope.enable = true;
      web-devicons.enable = true;
    };

    # fix this
    keymaps = [
      # fuzzy file
      {
        mode = ["n"];
        key = "<space>ff";
        action.__raw = "require('telescope.builtin').find_files";
      }

      # fuzzy grep
      {
        key = "<space>fg";
        mode = ["n"];
        action.__raw = "require('telescope.builtin').live_grep";
      }

      # fuzzy help
      {
        key = "<space>fh";
        mode = ["n"];
        action.__raw = "require('telescope.builtin').help_tags";
      }
    ];
  };
  environment.systemPackages = with pkgs; [ripgrep fzf fd];
}
