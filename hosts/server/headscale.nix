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
#
# The only node this repo enrols automatically is the server itself:
# `headscale-bootstrap` creates the owner and a reusable pre-auth key, and the
# server's own tailscaled reads that key off disk. It is the one host where that
# cannot deadlock, because it is also the host that mints keys. Every other host
# is enrolled by hand — see modules/custom/services/headscale-client.nix for why.
{
  config,
  pkgs,
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
  # Before that: make sure the owner and a reusable pre-auth key exist, and leave
  # the key on disk for this host's own tailscaled (`hosts/server/tailscale.nix`)
  # and for `nix run .#headscale-preauth-key` to copy into sops if another host
  # is ever opted into automatic enrolment.
  #
  # Headscale only validates keys it generated itself (it stores a bcrypt hash,
  # never the key), so this cannot be replaced by a value from sops: the control
  # plane is the source of truth and sops is at most a distribution channel.
  systemd.services.headscale-bootstrap = {
    description = "Provision the Headscale user and its reusable pre-auth key";
    wantedBy = [ "multi-user.target" ];
    requires = [ "headscale.service" ];
    after = [ "headscale.service" ];

    path = [
      config.services.headscale.package
      pkgs.coreutils
      pkgs.jq
    ];

    serviceConfig = {
      Type = "oneshot";
      UMask = "0077";
    };

    script = ''
      set -euo pipefail

      user="waynevanson"
      keyFile="${dataDir}/preauth-key"

      # headscale.service counts as started before it listens on the unix socket
      # the CLI talks to, so wait for it to answer instead of racing it.
      for _ in $(seq 1 60); do
        if headscale users list -o json > /dev/null 2>&1; then
          break
        fi
        sleep 1
      done

      if ! headscale users list -o json \
        | jq -e --arg user "$user" 'any((. // [])[]; .name == $user)' > /dev/null; then
        echo "creating headscale user $user"
        headscale users create "$user"
      fi

      userId=$(headscale users list -o json \
        | jq -r --arg user "$user" 'first((. // [])[] | select(.name == $user)).id')

      # Keep the key that was already handed out as long as Headscale still
      # knows it and it has not expired. Minting on every switch would invalidate
      # any copy that has been exported to sops.
      #
      # `preauthkeys list` only exposes the prefix (`hskey-auth-<prefix>-***`),
      # which is exactly what is needed to look the stored key up.
      keyIsLive=false
      if [[ -s "$keyFile" ]]; then
        prefix=$(cat "$keyFile")
        prefix=''${prefix#hskey-auth-}
        prefix=''${prefix:0:12}
        if headscale preauthkeys list -o json \
          | jq -e --arg masked "hskey-auth-$prefix-***" --argjson now "$(date +%s)" \
            'any((. // [])[]; .key == $masked and (.expiration == null or .expiration.seconds > $now))' \
            > /dev/null; then
          keyIsLive=true
        fi
      fi

      if [[ "$keyIsLive" == false ]]; then
        echo "minting a reusable pre-auth key for $user"
        headscale preauthkeys create -u "$userId" -e 8760h --reusable -o json \
          | jq -r '.key' > "$keyFile.tmp"
        mv "$keyFile.tmp" "$keyFile"
      fi
    '';
  };

  # A server that stays up for a year would otherwise keep an expired key on
  # disk, so re-run the check daily and mint a fresh one when needed.
  systemd.timers.headscale-bootstrap = {
    description = "Keep the Headscale pre-auth key provisioned";
    wantedBy = [ "timers.target" ];
    timerConfig.OnCalendar = "daily";
  };
  #
  # Backups are not wired up yet: add /var/lib/headscale to whatever picks up
  # /srv/data/backups (see postgresql.nix) if the tailnet should survive a
  # reinstall.
}
