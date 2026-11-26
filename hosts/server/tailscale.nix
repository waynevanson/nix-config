# The server joins its own tailnet as node `server`.
#
# Headscale (headscale.waynevanson.com) is only the control plane; the data path
# is WireGuard between the nodes themselves, direct where NAT traversal works and
# through Headscale's embedded DERP relay where it does not. Being on the tailnet
# is what lets the desktop reach this host from anywhere as `server` /
# `server.ts.waynevanson.com` rather than over the public address.
#
# Enrolment is declarative: the pre-auth key comes from sops, so the node is
# created on first boot and again after a reinstall without a manual
# `tailscale up`. See modules/custom/services/headscale-client.nix.
{ ... }:
{
  custom.services.headscale-client = {
    enable = true;

    # Keep systemd-resolved in charge here: nginx, ACME and every service on this
    # host resolve names through it, so a Headscale restart must not be able to
    # take DNS away from them. Other nodes still get MagicDNS, so
    # `server.ts.waynevanson.com` resolves from the desktop.
    extraUpFlags = [ "--accept-dns=false" ];
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
