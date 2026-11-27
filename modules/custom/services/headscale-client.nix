# Tailscale client pointed at the self-hosted Headscale control plane.
#
# Both hosts in this repo (server, desktop) use the same control URL, but they do
# not enrol the same way — and ordinary clients deliberately do *not* enrol
# themselves:
#
# Headscale is the only thing that can mint a pre-auth key (it keeps a bcrypt
# hash, so a key cannot be chosen in advance and shipped in sops), which means a
# client that enrols itself from configuration needs a credential that only the
# machine it is joining can produce. That is a chicken-and-egg problem, and a
# placeholder or stale key in sops turns it into a `tailscaled-autoconnect`
# restart loop rather than a node.
#
# So `authKeyFile` defaults to null: `tailscaled` runs, no autoconnect unit is
# generated, the node sits at `NeedsLogin`, and a human enrols it once. The
# server is the exception and opts in, because its key is minted locally by
# `headscale-bootstrap.service` — there is nothing to wait for.
#
# Any other host may opt in too, once the control plane has minted a key and it
# has been exported with `nix run .#headscale-preauth-key`; that is what makes a
# reinstall re-enrol itself.
{ config, lib, ... }:
let
  cfg = config.custom.services.headscale-client;
  loginServer = "https://headscale.waynevanson.com";
in
{
  options.custom.services.headscale-client = {
    enable = lib.mkEnableOption "joining the self-hosted Headscale tailnet";

    authKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        File containing a reusable pre-auth key, enabling automatic enrolment.

        Left null (the default) nothing is enrolled: `tailscaled` starts but no
        `tailscaled-autoconnect` unit exists, so the node waits for a manual
        `tailscale up` plus `headscale auth register` on the control plane.

        Set it to provision the node from configuration instead — the server
        points it at the key it mints for itself, and other hosts can point it
        at `config.sops.secrets.headscale-preauth-key.path` once that secret has
        been exported from the running control plane.
      '';
    };

    extraUpFlags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Extra flags appended to `tailscale up`. Only passed automatically when
        `authKeyFile` is set; otherwise include them in the manual
        `tailscale up ...` you run to enrol the node.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.tailscale = {
      enable = true;

      # This tailnet is self-hosted end to end; do not ship logs to Tailscale.
      disableUpstreamLogging = true;

      authKeyFile = cfg.authKeyFile;

      extraUpFlags = [ "--login-server" loginServer ] ++ cfg.extraUpFlags;
    };

    # nixpkgs only generates the unit when `authKeyFile` is set; defining
    # anything on it unconditionally would create an empty unit that never
    # enrols and never exits.
    systemd.services.tailscaled-autoconnect = lib.mkIf (cfg.authKeyFile != null) {
      # A sops-provided key only exists once sops-install-secrets has run. On the
      # server the ordering is set by the host, which generates the key itself.
      wants = [ "sops-install-secrets.service" ];
      after = [ "sops-install-secrets.service" ];

      # `tailscale up` only sends the key when tailscaled reports a login state,
      # so a failed attempt is only retried by restarting the unit.
      serviceConfig = {
        Restart = "on-failure";
        RestartSec = "30s";
      };
    };
  };
}
