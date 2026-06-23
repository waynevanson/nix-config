{
  config,
  inputs,
  pkgs,
  system,
  ...
}:
{
  programs.pi-coding-agent = {
    enable = true;

    package = inputs.self.packages.${system}.pi-coding-agent;

    extraPackages = with pkgs; [
      nodejs
      bun
    ];

    settings = {
      theme = "catppuccin-mocha";
      themes = [ "${config.programs.pi-coding-agent.configDir}/themes" ];
    };
  };

  home.file = {
    "${config.programs.pi-coding-agent.configDir}/themes/catppuccin-mocha.json".source =
      "${inputs.self.packages.${system}.pi-catppuccin-themes}/share/pi/themes/catppuccin-mocha.json";

    "${config.programs.pi-coding-agent.configDir}/themes/catppuccin-latte.json".source =
      "${inputs.self.packages.${system}.pi-catppuccin-themes}/share/pi/themes/catppuccin-latte.json";
  };
}
