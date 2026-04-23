{ inputs, system, ... }:
{
  xdg.configFile."opencode/opencode.json".text = builtins.toJSON {
    plugin = [ "${inputs.meridian.packages.${system}.meridian}/lib/meridian/plugins/merdian.ts" ];
  };
}
