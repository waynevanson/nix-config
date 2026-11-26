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
    ./headscale.nix
    ./jellyfin.nix
    ./keycloak.nix
    ./blog.nix
    ./postgresql.nix
    ./system.nix
    ./tailscale.nix
    ./web.nix
  ];

  hardware = {
    facter = {
      reportPath = ./facter.json;
      detected.dhcp.interfaces = [ "enp27s0" ];
    };
  };
}
