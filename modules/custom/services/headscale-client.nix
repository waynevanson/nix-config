# Tailscale client pointed at the self-hosted Headscale control plane.
#
# Both hosts in this repo (server, desktop) join the same tailnet with the same
# control URL and the same reusable sops pre-auth key, so those are constants
# here. Only the `tailscale up` flags differ per host, which is what
# `extraUpFlags` carries.
{ config, lib, ... }:
let
  cfg = config.custom.services.headscale-client;
  loginServer = "https://headscale.waynevanson.com";
in
{
  options.custom.services.headscale-client = {
    enable = lib.mkEnableOption "joining the self-hosted Headscale tailnet";

    extraUpFlags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra flags appended to `tailscale up`.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.tailscale = {
      enable = true;

      # This tailnet is self-hosted end to end; do not ship logs to Tailscale.
      disableUpstreamLogging = true;

      authKeyFile = config.sops.secrets.headscale-preauth-key.path;

      extraUpFlags = [ "--login-server" loginServer ] ++ cfg.extraUpFlags;
    };

    # The key is only on disk after sops-install-secrets runs, and on the server
    # the control plane itself may still be starting. Retry rather than needing a
    # manual `systemctl restart tailscaled-autoconnect`; the unit re-reads the key
    # on every attempt, so a rotated secret is picked up without further action.
    systemd.services.tailscaled-autoconnect = {
      wants = [ "sops-install-secrets.service" ];
      after = [ "sops-install-secrets.service" ];
      serviceConfig = {
        Restart = "on-failure";
        RestartSec = "30s";
      };
    };
  };
}
