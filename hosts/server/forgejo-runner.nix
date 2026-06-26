{
  pkgs,
  config,
  inputs,
  system,
  ...
}:
let
  tokenName = "forgejo-runner-token";
  tokenFileName = "forgejo-runner-token-file";
  instanceName = "default";
in
{
  sops = {
    secrets.${tokenName}.key = "forgejo/token";
    templates.${tokenFileName} = {
      # forgejo-runner reads just the token, no TOKEN= prefix
      content = config.sops.placeholder.${tokenName};
    };
  };

  services.forgejo-runner = {
    package = inputs.nixpkgs-forgejo-runner.legacyPackages.${system}.forgejo-runner;
    instances.${instanceName} = {
      enable = true;
      settings.runner.labels = [
        "nixos:docker://nixos/nix@sha256:72a13b0f42e3cc515945aa4250b772381d93c96d4bf93aa950b5c68defdab1dd"
        "ubuntu-latest:docker://catthehacker/ubuntu@sha256:711bf39b2df2300106ae46b0f82c994e0f7f7ab8d2372c1f11ca5f1492747f87"
      ];
      settings.server.connections.default.url = "https://git.waynevanson.com";
      # FIXME: replace with real UUID from Forgejo registration or /var/lib/gitea-runner/default/.runner
      settings.server.connections.default.uuid = "415288f7-359a-4d8b-8b9a-e79fb8c559db";
      secrets.server.connections.default.token_url = config.sops.templates.${tokenFileName}.path;
    };
  };

  virtualisation.podman.enable = true;
}
