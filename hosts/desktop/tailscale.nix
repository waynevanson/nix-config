# The desktop joins the self-hosted Headscale tailnet as node `nixos`.
#
# That is what makes `ssh server` / `server.ts.waynevanson.com` work from any
# network, and what VS Code Remote-SSH, Zed remote development and JetBrains
# Gateway connect through. Enrolment is declarative from the same sops pre-auth
# key as the server, so there is no `tailscale up --authkey ...` step after a
# reinstall.
{ ... }:
{
  custom.services.headscale-client = {
    enable = true;

    # MagicDNS is accepted by default, which is what resolves `server` through
    # the search domain and `*.ts.waynevanson.com`. The desktop is where a human
    # is sitting, so let the CLI run without sudo.
    extraUpFlags = [ "--operator=waynevanson" ];
  };
}
