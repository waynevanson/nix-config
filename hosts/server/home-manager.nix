{
  inputs,
  system,
  self,
  ...
}:
{
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = {
      inherit inputs system self;
    };
    users.zed =
      { self, ... }:
      {
        imports = [ self.homeModules.zed ];
        home = {
          username = "zed";
          homeDirectory = "/home/zed";
          stateVersion = "25.05";
        };
      };
  };
}
