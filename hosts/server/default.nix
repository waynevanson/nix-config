{
  self,
  inputs,
  ...
}:
{
  imports = [
    self.nixosModules.custom
    inputs.nix-minecraft.nixosModules.minecraft-servers
    ../../modules/tmux.nix
    ./forgejo.nix
    ./headscale.nix
    ./minecraft.nix
    # ./wordpress-lx.nix
    ./wordpress-wayne.nix
    ./forgejo-runner.nix
    ./atticd.nix
    ./garage.nix
    ./web.nix
    ./procurare.nix
    ./system.nix
    "${inputs.nixpkgs-forgejo-runner}/nixos/modules/services/continuous-integration/forgejo-runner.nix"
    ./disko-configuration
    ./containers.nix
  ];
}
