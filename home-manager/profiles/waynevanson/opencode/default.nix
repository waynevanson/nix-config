{
  pkgs,
  config,
  ...
}:
{
  sops.secrets.opencode-server-password.key = "opencode/server-password";

  xdg.configFile."opencode/opencode.json".source = ./opencode.json;
  xdg.configFile."opencode/plugins".source = ./plugins;
  xdg.configFile."opencode/skills".source = ./skills;
  xdg.configFile."opencode/agents".source = ./agents;
  xdg.configFile."opencode/instructions".source = ./instructions;

  home.packages = [
    pkgs.opencode
    (pkgs.writeShellApplication {
      name = "opencode-remote";
      runtimeInputs = [ pkgs.opencode ];
      text = ''
        OPENCODE_SERVER_PASSWORD="$(${pkgs.coreutils}/bin/tr -d '\n' < ${config.sops.secrets.opencode-server-password.path})"
        export OPENCODE_SERVER_PASSWORD
        OPENCODE_SERVER_USERNAME=opencode
        export OPENCODE_SERVER_USERNAME
        exec ${pkgs.lib.getExe pkgs.opencode} attach https://opencode.waynevanson.com "$@"
      '';
    })
  ];
}
