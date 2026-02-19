{
  programs.nixvim = {
    plugins = {
      conform-nvim = {
        enable = true;
        settings = {
          lsp_format = "fallback";
          formatters_by_ft = {
            nix = ["alejandra"];

            javascript = ["prettier"];
            typescript = ["prettier"];
            typescriptreact = ["prettier"];
            javascriptreact = ["prettier"];
          };
        };
      };

      none-ls = {
        enable = true;
        sources.formatting.prettier = {
          enable = true;
          disableTsServerFormatter = false;
        };
      };
    };

    autoCmd = [
      # format on save
      {
        event = "BufWritePre";
        callback = {__raw = "function() require('conform').format({}) end";};
      }
    ];
  };
}
