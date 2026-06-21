{
  self,
  inputs,
  ...
}:
{
  imports = [
    self.nixosModules.custom
    inputs.nix-minecraft.nixosModules.minecraft-servers
    ./forgejo.nix
    ./opencode.nix
    ./zed.nix
    ./minecraft.nix
    # ./wordpress-lx.nix
    ./wordpress-wayne.nix
    # ./forgejo-runner.nix
    ./atticd.nix
    ./garage.nix
    ./web.nix
    ./home-manager.nix
    ./system.nix
    ./disko-configuration
  ];
}
