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
`/run/headscale/headscale.sock`, which only root may open, so use
`sudo headscale …`.

## Enrolment

Enrolment is split in two on purpose, because a pre-auth key can only be minted
by the running control plane (Headscale stores a bcrypt hash, never the key, so
sops cannot hold one). A client configured to enrol itself therefore depends on
a value that only the machine it is joining can produce — the chicken-and-egg
problem. Rather than paper over that with a placeholder secret, nodes are
enrolled explicitly.

### The server enrols itself

`headscale-bootstrap.service` in `hosts/server/headscale.nix` runs on every boot
and once a day and:

1. creates the user `waynevanson` if it is missing;
2. keeps `/var/lib/headscale/preauth-key` while Headscale still knows that
   prefix and its expiry is in the future;
3. otherwise mints a reusable key with a one-year expiry and writes it there
   (root-only, inside the state directory, so it is in the backup set).

The server's own `tailscaled` then enrols from that file
(`hosts/server/tailscale.nix`), which is the one case with no ordering problem:
the host minting the key is the host using it.

```sh
nix run .#server switch
sudo systemctl status headscale-bootstrap.service headscale.service
sudo tailscale status                      # expect: server  100.64.x.x
```

### Every other host is enrolled by hand, once

`custom.services.headscale-client.authKeyFile` defaults to `null`, so the module
starts `tailscaled` but generates **no** `tailscaled-autoconnect` unit: the node
sits at `NeedsLogin` instead of retrying forever with a key that does not exist
yet. Enrol it after the server is up:

```sh
# on the client (desktop, laptop, …)
sudo tailscale up --login-server https://headscale.waynevanson.com --operator=waynevanson
# tailscaled prints https://headscale.waynevanson.com/register/hskey-authreq-…
```

Then on the server (that URL prints the same command):

```sh
sudo headscale auth register --auth-id hskey-authreq-… --user waynevanson
sudo headscale nodes list
```

It is a one-time action per machine: the node identity lives in
`/var/lib/tailscale`, so tailscaled reconnects on its own from then on and only
a reinstall loses it. `sudo headscale auth approve --auth-id …` is the
equivalent when re-authenticating an existing node.

### Opting a host into automatic enrolment

If a machine should re-enrol itself after a reinstall, export the key the control
plane minted and point that host at it:

```sh
nix run .#headscale-preauth-key      # ssh + `sudo cat` on the server, then `sops set`
```

```nix
custom.services.headscale-client.authKeyFile =
  config.sops.secrets.headscale-preauth-key.path;
```

That is distribution, not pre-distribution: it only works once the server is
running, which is exactly why it is not the default. Nodes are independent
entries in Headscale whatever the source of the key, because the node identity
is `tailscaled`'s own key in `/var/lib/tailscale`.

### Rotating the key

Enrolled nodes are unaffected — they authenticate with their node key:

```sh
sudo rm /var/lib/headscale/preauth-key
sudo systemctl start headscale-bootstrap.service
nix run .#headscale-preauth-key      # only if some host uses the sops copy
```

`sudo headscale preauthkeys list` shows the live keys (only the prefix is
printable); `sudo headscale preauthkeys expire --id <id>` retires a leaked one.

## Enrol the desktop

After the manual enrolment above, `tailscale` on the desktop needs no sudo when
it was started with `--operator=waynevanson`:

```sh
tailscale status
ssh server                                  # or server.ts.waynevanson.com
tailscale netcheck                          # DERP relay `waynevanson`, STUN :3478
```

VS Code Remote-SSH, Zed remote development and JetBrains Gateway all work off
that host entry; `hosts/server/system.nix` enables `nix-ld` so the VS Code server
and extension binaries run on NixOS.

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
sudo headscale nodes list
sudo headscale routes list
sudo headscale routes enable -r <route-id>
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
  The directory also holds `preauth-key`, minted by
  `headscale-bootstrap.service`; it is regenerated if lost, but then has
  to be re-exported for any host that opted into automatic enrolment.
- `headscale-bootstrap.service` is idempotent and safe to re-run:
  `sudo systemctl start headscale-bootstrap.service`, then `journalctl -u` it
  if the server's own node will not come up.
- `--accept-dns=false` on the server: the host keeps systemd-resolved, so a
  Headscale outage cannot take DNS away from nginx/ACME. Clients still get
  MagicDNS.
- OIDC login through the existing Keycloak (`keycloak.waynevanson.com`) is not
  configured; it needs a client secret in sops (`modules/sops.nix`) plus
  `settings.oidc.issuer` / `client_id` / `client_secret_path`.
