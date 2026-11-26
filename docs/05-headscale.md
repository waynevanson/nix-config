# Headscale

Self-hosted control plane for Tailscale clients on the server. See
`hosts/server/headscale.nix` for the config.

- Listens on `127.0.0.1:8085` in plain HTTP; nginx terminates TLS for
  `https://headscale.waynevanson.com` with the shared `waynevanson.com`
  certificate.
- State: `/var/lib/headscale` (SQLite `db.sqlite`, `noise_private.key` and
  `derp_server_private.key`). The only firewall change is UDP 3478 (STUN for the
  embedded DERP relay), plus a matching router forward.
- Nodes talk WireGuard to each other; Headscale only coordinates. Direct
  connections are tried first, then Headscale's **own** DERP relay
  (`settings.derp.server`, region 999), which it serves at
  `https://headscale.waynevanson.com/derp` on the same vhost. `settings.derp.urls`
  is intentionally empty: the public Tailscale relay map is not used, so no
  tailnet traffic depends on Tailscale infrastructure.

## Before deploying

Create the DNS record so clients can reach it:

```sh
headscale.waynevanson.com  A/AAAA  <server's public address>
```

Also forward **UDP 3478** to the server on the router. That is STUN for the
embedded DERP relay (`networking.firewall.allowedUDPPorts = [ 3478 ]` in
`headscale.nix` already opens it on the host). Relaying still works over 443
without it, but clients behind NAT will not learn their mapped endpoint through
this region, so direct connections are harder to establish.

STUN does **not** go through nginx: only the relay (`/derp`, WebSocket over 443)
is proxied. `stun_listen_addr` makes Headscale bind its own UDP socket, and
clients are told to send UDP to `<server_url host>:3478` directly, so the router
forward has to land on this host. Pointing nginx at it is neither needed nor
possible without a `stream {}` block, since nginx is only listening on TCP 80/443
here.

The certificate does not need this record: validation is DNS-01 via the
Spaceship API, and lego creates the `_acme-challenge.headscale.waynevanson.com`
TXT record itself.

Then:

```sh
nix run .#server switch
systemctl status headscale.service nginx.service
curl -s https://headscale.waynevanson.com/health   # {"status":"pass"}
```

`headscale` is on the server's `PATH`; the CLI talks to the running server over
`/run/headscale/headscale.sock`.

## Enrolment (sops, no manual `tailscale up`)

Both hosts are enrolled from the same reusable pre-auth key, through the shared
module `modules/custom/services/headscale-client.nix`:

| host | node name | instantiated in | flags |
| --- | --- | --- | --- |
| server | `server` | `hosts/server/tailscale.nix` | `--accept-dns=false` |
| desktop | `nixos` | `hosts/desktop/tailscale.nix` | `--operator=waynevanson` |

The module points `services.tailscale.authKeyFile` at the sops secret
`headscale/preauth-key` and adds `--login-server`, so `tailscaled-autoconnect`
enrols the node on boot and again after a reinstall. Nodes are independent
entries in Headscale (`headscale nodes list`) even though they share a key: the
node identity is `tailscaled`'s own key in `/var/lib/tailscale`.

The sops file currently holds a placeholder. After the first switch with
Headscale running, mint a reusable key and store it (one time, from this
machine):

```sh
ssh waynevanson@<server-lan-ip>            # direct/LAN path, not the tailnet yet
headscale users create waynevanson
headscale users list                       # note the numeric ID
headscale preauthkeys create -u <ID> -e 8760h --reusable
headscale preauthkeys list                 # confirm `reusable: true`
```

```sh
sops set .sops.secrets.yaml '["headscale"]["preauth-key"]' '"<key from above>"'
nix run .#server switch
```

The unit retries on failure, so after the switch it picks the new key up on the
next attempt (`RestartSec = 30s`). To skip the wait:

```sh
systemctl restart tailscaled-autoconnect   # on the server
sudo tailscale status                      # expect: server  100.64.x.x
```

## Enrol the desktop

The desktop is already configured: `nixos-rebuild switch` and it joins as
`nixos`, reading the same sops secret with the admin age key
(`/home/waynevanson/.config/sops/age/keys.txt`). Because it passes
`--operator=waynevanson`, the CLI needs no sudo there:

```sh
tailscale status
ssh server                                  # or server.ts.waynevanson.com
tailscale netcheck                          # DERP relay `waynevanson`, STUN :3478
```

VS Code Remote-SSH, Zed remote development and JetBrains Gateway all work off
that host entry; `hosts/server/system.nix` enables `nix-ld` so the VS Code server
and extension binaries run on NixOS.

To give each host its own key instead of sharing a reusable one (so revoking one
would not touch the other), the `preauthKeySecret` constant in
`modules/custom/services/headscale-client.nix` has to become a per-host option
first; the shared reusable key is what the module supports today.

SSH is allowed on `tailscale0` via `hosts/server/tailscale.nix`, but port 22 is
currently open on **every** interface too (`services.openssh.openFirewall`
defaults to true, which is what `nix run .#server` uses over the public
address). Once `tailscale status` lists the node, set
`services.openssh.openFirewall = false;` in `hosts/server/tailscale.nix` so the
tailnet rule is the only way in. The desktop's key (`waynevanson@nixos`) is
already in the server's `authorizedKeys`; a laptop with a different key needs it
added to `hosts/server/system.nix`.

To reach the whole LAN (Jellyfin, the router, other machines) rather than just
the server, make the server a subnet router instead: set
`services.tailscale.useRoutingFeatures = "server"` and pass
`"--advertise-routes=<lan>/24"` in `custom.services.headscale-client.extraUpFlags`
on the server (plus `--accept-routes` on the desktop), then approve it:

```sh
headscale nodes list
headscale routes list
headscale routes enable -r <route-id>
```

## Notes

- Headscale 0.29 speaks the Tailscale protocol; clients older than v1.80 are
  rejected (`minimum_version` in the logs).
- `derp.server.stun_listen_addr must be set if derp.server.enabled is true`
  means the `stun_listen_addr` line went missing; the relay will not start
  without it.
- Clients report the relay in `tailscale netcheck` / `tailscale debug derp-map`
  as `waynevanson` (`region_id` 999) with a `:3478` STUN address. If it shows up
  but is unreachable, the router forward is missing.
- The DERP server key lives at `/var/lib/headscale/derp_server_private.key`; it
  is generated on first start and belongs in the backup set with the SQLite
  database and `noise_private.key`.
- `WRN listening without TLS but ServerURL does not start with http://` is
  expected for the reverse-proxy setup.
- `ephemeral_node_inactivity_timeout` is emitted by the module default and is
  deprecated upstream; harmless.
- Back up `/var/lib/headscale`. Without it every node must re-authenticate and
  the noise/DERP keys are lost. Not wired into `services.postgresqlBackup` yet.
- `--accept-dns=false` on the server: the host keeps systemd-resolved, so a
  Headscale outage cannot take DNS away from nginx/ACME. Clients still get
  MagicDNS.
- OIDC login through the existing Keycloak (`keycloak.waynevanson.com`) is not
  configured; it needs a client secret in sops (`modules/sops.nix`) plus
  `settings.oidc.issuer` / `client_id` / `client_secret_path`.
