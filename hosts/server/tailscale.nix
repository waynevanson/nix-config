# The server joins its own tailnet as node `server`.
#
# Headscale (headscale.waynevanson.com) is only the control plane; the data path
# is WireGuard between the nodes themselves, direct where NAT traversal works and
# through Headscale's embedded DERP relay where it does not. Being on the tailnet
# is what lets the desktop reach this host from anywhere as `server` /
# `server.ts.waynevanson.com` rather than over the public address.
#
# This is the only host that opts into automatic enrolment, and it is the only
# one that safely can: `headscale-bootstrap.service` (hosts/server/headscale.nix)
# mints the key on this machine, so there is no "wait for the control plane to
# produce a key that only the control plane can produce" loop. Every other host
# is enrolled by hand — see modules/custom/services/headscale-client.nix.
{ ... }:
{
  custom.services.headscale-client = {
    enable = true;

    # Written by headscale-bootstrap.service. Not a pre-distributed secret: it
    # never travels, and it exists only on the host that mints it.
    authKeyFile = "/var/lib/headscale/preauth-key";

    # Keep systemd-resolved in charge here: nginx, ACME and every service on this
    # host resolve names through it, so a Headscale restart must not be able to
    # take DNS away from them. Other nodes still get MagicDNS, so
    # `server.ts.waynevanson.com` resolves from the desktop.
    extraUpFlags = [ "--accept-dns=false" ];
  };

  # The key only exists once the control plane is up and provisioned, so order
  # the client behind that instead of letting it start with an unreadable file.
  systemd.services.tailscaled-autoconnect = {
    wants = [ "headscale-bootstrap.service" ];
    after = [ "headscale-bootstrap.service" ];
  };

  # Allow SSH from the tailnet. Port 22 is still open on every interface because
  # `services.openssh.openFirewall` defaults to true (the `nix run .#server` app
  # relies on that to reach the public address), so this rule only becomes the
  # sole way in once the line below is uncommented — do that only after
  # `tailscale status` lists the node on the server, because until the pre-auth
  # key is real the public port is the only working session.
  #
  # services.openssh.openFirewall = false;
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 22 ];
}
