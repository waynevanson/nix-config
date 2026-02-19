{
  modularise = args: path: options: createConfig: let
    config' = args.lib.getAttrByPath path args.config;
    configured = createConfig config';
  in {
    options = args.lib.setAttrByPath path options;
    config = args.lib.setAttrByPath path configured;
  };
}
