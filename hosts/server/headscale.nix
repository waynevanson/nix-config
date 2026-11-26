# Headscale (headscale.waynevanson.com)
#
# Self-hosted control plane for Tailscale clients. Headscale only coordinates
# the tailnet: it authenticates nodes, hands out 100.64.0.0/10 addresses and
# distributes WireGuard public keys. The traffic itself is WireGuard between the
# nodes, direct where NAT traversal works and relayed through DERP where it does
# not.
#
# Headscale listens on loopback in plain HTTP and terminates no TLS: nginx owns
# :443 with the shared `waynevanson.com` certificate. The only port opened in
# the firewall is UDP 3478, STUN for Headscale's own DERP relay.
#
# State lives in /var/lib/headscale (SQLite database, noise private key and DERP
# server key). Back that directory up: losing it means every node has to
# re-authenticate, and the keys cannot be recovered.
{
  ...
}:
let
  domain = "headscale.waynevanson.com";
  # 8080 is Keycloak; the rest of the range is free.
  port = 8085;
  dataDir = "/var/lib/headscale";
in
{
  services.headscale = {
    enable = true;
    address = "127.0.0.1";
    port = port;

    settings = {
      # The URL clients are configured with (`tailscale up --login-server`).
      server_url = "https://${domain}";

      # Upstream develops and optimises against SQLite; Postgres support is kept
      # for legacy installs only.
      database.type = "sqlite";

      # Generated on first start by Headscale itself, so it needs no sops entry.
      noise.private_key_path = "${dataDir}/noise_private.key";

      # Tailscale clients only accept addresses inside these ranges. `random`
      # avoids handing out neighbouring addresses and keeps collisions unlikely
      # if this tailnet is ever merged with another.
      prefixes = {
        v4 = "100.64.0.0/10";
        v6 = "fd7a:115c:a1e0::/48";
        allocation = "random";
      };

      # MagicDNS gives every node `<hostname>.ts.waynevanson.com` inside the
      # tailnet. The base domain must differ from `server_url`'s domain, and it
      # is only ever resolved for tailnet clients (no public DNS records
      # required). Search domains make `ssh server` work without the suffix.
      dns = {
        magic_dns = true;
        base_domain = "ts.waynevanson.com";
        search_domains = [ "ts.waynevanson.com" ];
        override_local_dns = true;
        # Used for names outside the tailnet while `override_local_dns` is on.
        nameservers.global = [
          "1.1.1.1"
          "9.9.9.9"
        ];
      };

      # Headscale's own DERP relay: nodes that cannot punch through NAT are
      # relayed here instead of through Tailscale's infrastructure. Headscale
      # adds the region to the DERP map itself and serves it at
      # `<server_url>/derp`, i.e. on the nginx vhost below, so there is no
      # separate `derper` to run.
      derp = {
        # Deliberately empty. Keeping the public map would leave clients
        # latency-probing Tailscale's regions, which often beat a single
        # self-hosted one; an empty map means this region is the only option.
        urls = [ ];
        auto_update_enabled = false;

        server = {
          enabled = true;
          # Arbitrary, but stable: it identifies this relay inside tailnet DERP
          # maps, so changing it later makes clients re-probe.
          region_id = 999;
          region_code = "waynevanson";
          region_name = "waynevanson";
          # Required while the server is enabled. `private_key_path` is left at
          # the module default (${dataDir}/derp_server_private.key), generated
          # by Headscale on first start like the noise key.
          stun_listen_addr = "0.0.0.0:3478";
        };
      };

      log.level = "info";
    };
  };

  # The name has to be on the shared certificate. Validation is DNS-01 through
  # the Spaceship API, so issuing only needs a TXT record that lego creates —
  # the A/AAAA record below is for clients reaching Headscale, not for the
  # certificate.
  security.acme.certs."waynevanson.com".extraDomainNames = [ domain ];

  services.nginx.virtualHosts.${domain} = {
    useACMEHost = "waynevanson.com";
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString port}";
      # tailscaled upgrades the control connection (`tailscale-control-protocol`)
      # and keeps it open for the life of the node, so nginx must not buffer the
      # stream or time it out on the default 60s.
      proxyWebsockets = true;
      extraConfig = ''
        proxy_buffering off;
        proxy_request_buffering off;
        proxy_read_timeout 12h;
        proxy_send_timeout 12h;
        client_max_body_size 0;
      '';
    };
  };

  # STUN for the embedded DERP. Clients fall back to relaying over 443 if this
  # is unreachable, but then their NAT traversal through this region is worse,
  # so the router needs a matching UDP 3478 forward.
  networking.firewall.allowedUDPPorts = [ 3478 ];

  # `networking.extraHosts` in system.nix already resolves this name to
  # loopback on the host itself, so a node running here reaches Headscale
  # without hairpinning out through the router.
  #
  # Backups are not wired up yet: add /var/lib/headscale to whatever picks up
  # /srv/data/backups (see postgresql.nix) if the tailnet should survive a
  # reinstall.
}
