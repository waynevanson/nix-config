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
in
{
  programs.pi-coding-agent = {
    enable = true;

    package = inputs.self.packages.${system}.pi-coding-agent;

    extraPackages = with pkgs; [
      nodejs
      bun
    ];

    context = ./pi/AGENTS.md;

    settings = {
      defaultProvider = "moonshotai";
      defaultModel = "kimi-k2.7-code";
      theme = "catppuccin-latte/catppuccin-mocha";
      editorPaddingX = 1;
      themes = [ "${configDir}/themes" ];
      skills = [ "${configDir}/skills" ];
    };
  };

  home.file = {
    "${configDir}/themes/catppuccin-mocha.json".source =
      "${inputs.self.packages.${system}.pi-catppuccin-themes}/share/pi/themes/catppuccin-mocha.json";

    "${configDir}/themes/catppuccin-latte.json".source =
      "${inputs.self.packages.${system}.pi-catppuccin-themes}/share/pi/themes/catppuccin-latte.json";

    # Skills
    "${configDir}/skills/grill/SKILL.md".source = ./pi/skills/grill/SKILL.md;
    "${configDir}/skills/caveman/SKILL.md".source = ./pi/skills/caveman/SKILL.md;
  };
}
