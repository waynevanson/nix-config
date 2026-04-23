{
  config,
  ...
}:
{
  xdg.configFile."opencode/opencode.json".text = builtins.toJSON {
    plugin = [ "opencode-claude-auth@latest" ];
  };
}
