{
  self,
  inputs,
  ...
}:
{
  imports = [
    self.nixosModules.custom
    inputs.nix-minecraft.nixosModules.minecraft-servers
    inputs.nix-openclaw.nixosModules.openclaw-gateway
    ../../modules/tmux.nix
    ./forgejo.nix
    ./openclaw.nix
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
