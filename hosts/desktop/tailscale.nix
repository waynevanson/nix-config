# The desktop joins the self-hosted Headscale tailnet as node `nixos`.
#
# That is what makes `ssh server` / `server.ts.waynevanson.com` work from any
# network, and what VS Code Remote-SSH, Zed remote development and JetBrains
# Gateway connect through.
#
# It does *not* enrol itself. Headscale stores only a bcrypt hash of a pre-auth
# key, so a key cannot be written into sops ahead of time: only the running
# control plane can mint one. Pointing `authKeyFile` at a secret that does not
# hold a live key yet is the chicken-and-egg case, and it fails as a
# `tailscaled-autoconnect` restart loop rather than as an obvious error.
#
# Enrol once instead (the URL tailscaled prints gives the command to run on the
# server):
#
#   sudo tailscale up --login-server https://headscale.waynevanson.com \
#     --operator=waynevanson
#   sudo headscale auth register --auth-id hskey-authreq-… --user waynevanson
#
# After that the node identity lives in /var/lib/tailscale and tailscaled
# reconnects on its own; only a reinstall loses it. See docs/05-headscale.md.
{ ... }:
{
  custom.services.headscale-client = {
    enable = true;

    # MagicDNS is accepted by default, which is what resolves `server` through
    # the search domain and `*.ts.waynevanson.com`. The desktop is where a human
    # is sitting, so `tailscale up` also hands the CLI to waynevanson.
    #
    # Inert while `authKeyFile` is unset (nixpkgs only applies these flags when it
    # is), and kept here so opting in later needs only the key.
    extraUpFlags = [ "--operator=waynevanson" ];
  };
}
