{
  self,
  ...
}:
{
  imports = [
    ../../modules
    self.nixosModules.sops
    ./disko-configuration
    ./garage.nix
    ./system.nix
    ./web.nix
  ];

  hardware = {
    facter = {
      reportPath = ./facter.json;
      detected.dhcp.interfaces = [ "enp27s0" ];
    };
  };
}
