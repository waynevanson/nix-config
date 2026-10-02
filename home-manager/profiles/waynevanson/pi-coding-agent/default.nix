{
  config,
  inputs,
  pkgs,
  system,
  ...
}:
let
  cfg = config.programs.pi-coding-agent;
  configDir = cfg.configDir;
  moonshot-secret = config.sops.secrets.moonshotai-api-key.path;
  deepseek-secret = config.sops.secrets.deepseek-token.path;
  pi-wrapped = pkgs.writeShellApplication {
    name = "pi";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      MOONSHOT_API_KEY="$(${pkgs.coreutils}/bin/tr -d '\n' < ${moonshot-secret})"
      export MOONSHOT_API_KEY

      KIMI_API_KEY="$MOONSHOT_API_KEY"
      export KIMI_API_KEY

      DEEPSEEK_API_KEY="$(${pkgs.coreutils}/bin/tr -d '\n' < ${deepseek-secret})"
      export DEEPSEEK_API_KEY

      exec ${inputs.self.packages.${system}.pi-coding-agent}/bin/pi "$@"
    '';
  };
in
{
  programs.pi-coding-agent = {
    enable = true;
    package = pi-wrapped;
    extraPackages = with pkgs; [
      nodejs
      bun
      inputs.self.packages.${system}.codelens
    ];
    settings = {
      defaultProvider = "deepseek";
      defaultModel = "deepseek-v4-pro";
      theme = "catppuccin-latte/catppuccin-mocha";
      editorPaddingX = 1;
      themes = [ "${configDir}/themes" ];
      skills = [ "${configDir}/skills" ];
      extensions = [ "${configDir}/extensions" ];
      packages = [ ];
    };
  };

  sops.secrets.moonshotai-api-key.key = "moonshotai/api-key";
  sops.secrets.deepseek-token.key = "deepseek/token";

  # todo: abstract out better
  # todo: create our own qna and questionairre tools becuase there are some bugs.
  home.file = {
    # todo: rename themes to `pi-coding-agent`
    "${configDir}/themes/catppuccin-mocha.json".source = "${
      inputs.self.packages.${system}.pi-catppuccin-themes
    }/share/pi/themes/catppuccin-mocha.json";

    "${configDir}/themes/catppuccin-latte.json".source = "${
      inputs.self.packages.${system}.pi-catppuccin-themes
    }/share/pi/themes/catppuccin-latte.json";
  };
}
