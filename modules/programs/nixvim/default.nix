{
  config,
  lib,
  ...
}: {
  options.waynevanson.programs.nixvim.enable = lib.mkEnableOption {};

  config = lib.mkIf config.waynevanson.programs.nixvim.enable {
    programs.nixvim = {
      extraConfigLua = ''
        -- In your init.lua
        vim.keymap.set('n', '<C-H>', ':TmuxNavigateLeft<cr>', { silent = true })
        vim.keymap.set('n', '<C-L>', ':TmuxNavigateRight<cr>', { silent = true })
      '';

      enable = true;
      defaultEditor = true;
      viAlias = true;
      vimAlias = true;
      opts = {
        number = true;
        relativenumber = true;
        tabstop = 4;
        shiftwidth = 4;
        expandtab = true;
      };
      clipboard.register = "unnamedplus";

      lsp = {
        inlayHints.enable = true;
      };

      plugins.gitsigns.enable = true;
      plugins.vimux.enable = true;
      plugins.direnv.enable = true;
      plugins.treesitter.enable = true;
      plugins.tmux-navigator.enable = true;

      plugins = {
        lspconfig.enable = true;
        cmp = {
          enable = true;
        };
        cmp-nvim-lsp.enable = true;
      };

      lsp.servers.nil.enable = true;
      lsp.servers.ts_ls.enable = true;
      lsp.servers.rust_analyzer.enable = true;
      lsp.servers.postgres_lsp.enable = true;
      lsp.servers.html.enable = true;
      lsp.servers.jsonls.enable = true;
      lsp.servers.emmet_language_server.enable = true;
      lsp.servers.docker_langauge_server.enable = true;
      lsp.servers.docker_compose_langauge_server.enable = true;
      lsp.servers.cssls.enable = true;
      lsp.servers.yamlls.enable = true;

      lsp.servers.elixirls.enable = false;
      lsp.servers.lua_ls.enable = false;
      lsp.servers.nginx_language_server.enable = false;
      lsp.servers.metals.enable = false;
      lsp.servers.kotlin_language_server.enable = false;
      lsp.servers.java_language_server.enable = false;
      lsp.servers.nil_ls.enable = false;
    };
  };
}
