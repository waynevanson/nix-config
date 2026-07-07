{
  self,
  inputs,
  ...
}:
{
  imports = [
    self.nixosModules.custom
    inputs.nix-minecraft.nixosModules.minecraft-servers
    "${inputs.nixpkgs-forgejo-runner}/nixos/modules/services/continuous-integration/forgejo-runner.nix"
    ./containers.nix
    ./disko-configuration
    # ./atticd.nix
    ../../modules/tmux.nix
    ./forgejo.nix
    # ./forgejo-runner.nix
    # ./garage.nix
    ./headscale.nix
    ./minecraft.nix
    # ./procurare.nix
    ./system.nix
    ./web.nix
    # ./wordpress-lx.nix
    ./wordpress-wayne.nix
  ];
}
