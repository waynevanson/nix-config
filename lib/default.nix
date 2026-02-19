{
  # functional lense for creating modules
  modularise = args: path: {
    options,
    config,
  }: let
    config' = config (args.lib.getAttrByPath args.config);
  in {
    options = args.lib.setAttrByPath path options;
    config = args.lib.setAttrByPath path config';
  };
}
