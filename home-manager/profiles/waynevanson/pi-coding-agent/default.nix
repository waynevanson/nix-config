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
    context = ./AGENTS.md;
    settings = {
      defaultProvider = "deepseek";
      defaultModel = "deepseek-v4-pro";
      theme = "catppuccin-latte/catppuccin-mocha";
      editorPaddingX = 1;
      themes = [ "${configDir}/themes" ];
      skills = [ "${configDir}/skills" ];
      extensions = [ "${configDir}/extensions" ];
      packages = [
        "git:git@github.com:amosblomqvist/pi-observational-memory.git"
        "git:git@github.com:HazAT/pi-interactive-subagents.git"
        "git:git@github.com:amosblomqvist/learn.git"
      ];
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
    # Skills
    "${configDir}/skills/grill/SKILL.md".source = ./skills/grill/SKILL.md;
    "${configDir}/skills/caveman/SKILL.md".source = ./skills/caveman/SKILL.md;

    # Extensions
    # "${configDir}/extensions/codelens.ts".source = "${
    #   inputs.self.packages.${system}.codelens
    # }/lib/node_modules/@fodx/codelens/adapters/pi/codelens.extension.ts";

    "${configDir}/extensions/qna.ts".source = "${
      inputs.self.packages.${system}.pi-coding-agent
    }/lib/node_modules/@earendil-works/pi-coding-agent/examples/extensions/qna.ts";
    "${configDir}/extensions/questionnaire.ts".source = "${
      inputs.self.packages.${system}.pi-coding-agent
    }/lib/node_modules/@earendil-works/pi-coding-agent/examples/extensions/questionnaire.ts";

    # amosblomqvist/pi-config extensions
    "${configDir}/extensions/browser".source = "${
      inputs.self.packages.${system}.pi-config-extensions
    }/browser";
    "${configDir}/extensions/web-fetch".source = "${
      inputs.self.packages.${system}.pi-config-extensions
    }/web-fetch";
    # "${configDir}/extensions/web-search".source = "${inputs.self.packages.${system}.pi-config-extensions}/web-search";
    "${configDir}/extensions/prompt-snippets".source = "${
      inputs.self.packages.${system}.pi-config-extensions
    }/prompt-snippets";
    # "${configDir}/extensions/ask-user-question.ts".source = "${
    #   inputs.self.packages.${system}.pi-config-extensions
    # }/ask-user-question.ts";
  };
}
