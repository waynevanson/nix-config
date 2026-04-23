{
  config,
  ...
}:
{
  xdg.configFile."opencode/opencode.json".text = builtins.toJSON {
    plugin = [ config.services.meridian.opencode.pluginPath ];
  };
}
