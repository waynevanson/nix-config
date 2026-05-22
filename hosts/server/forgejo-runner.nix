{
  pkgs,
  config,
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
      content = ''
        TOKEN=${config.sops.placeholder.${tokenName}}
      '';

    };
  };

  # https://github.com/NixOS/nixpkgs/blob/nixos-unstable/nixos/modules/services/continuous-integration/gitea-actions-runner.nix
  services.gitea-actions-runner = {
    package = pkgs.forgejo-runner;
    instances.${instanceName} = {
      enable = true;
      name = "default";
      url = "https://git.waynevanson.com";
      labels = [
        "nixos:docker://nixos/nix@sha256:72a13b0f42e3cc515945aa4250b772381d93c96d4bf93aa950b5c68defdab1dd"
      ];
      token = "sup bro";
      # tokenFile = config.sops.templates.${tokenFileName}.path;
    };
  };

  # it's hanging here for reasons unknown due to virtualisation
  systemd.user.services.dbus-broker.restartIfChanged = false;

  virtualisation.podman.enable = true;
}
