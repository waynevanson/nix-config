#  todo: find way to get runner token from forgejo instance and put it in here.
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
      settings.server.connections.default.uuid = "904151e1-e653-4241-91fc-008354d78e44";
      # Runner containers need to reach Forgejo at git.waynevanson.com.
      # /etc/hosts maps that to 127.0.0.1, so containers must share the host network namespace
      # and also carry that host entry themselves for DNS resolution.
      settings.container.network = "host";
      settings.container.options = "--add-host git.waynevanson.com:127.0.0.1";
      secrets.server.connections.default.token_url = config.sops.templates.${tokenFileName}.path;
    };
  };

  virtualisation.podman.enable = true;
}
