# Keycloak (`keycloak.waynevanson.com`)

[Keycloak](https://www.keycloak.org/) provides OIDC/OAuth2/SAML for the other
services on the server. It runs from `hosts/server/keycloak.nix`:

- nginx terminates TLS with the shared `waynevanson.com` certificate and
  reverse-proxies to `127.0.0.1:8080`.
- Keycloak listens on loopback only, with `proxy-headers = xforwarded` so it
  builds `https://keycloak.waynevanson.com` URLs.
- Data lives in the local PostgreSQL instance (`keycloak` role and database are
  provisioned by the NixOS module). State/cache is in `/var/lib/keycloak`.
- The database connection is TLS (`hostssl` is the only rule `postgresql.nix`
  accepts on loopback) and validated against the system CA roots. The roots are
  re-exported through OpenSSL first: NSS' `ca-bundle.crt` contains
  `TRUSTED CERTIFICATE` blocks with extra attributes that make the JDBC driver
  fail with `java.io.IOException: extra data at the end`.
- `database.host` has to stay `localhost` (the module only provisions the role
  then), so `postgresql.nix` allows both loopback addresses over TLS.

Both secrets are in `.sops.secrets.yaml`:

| Key                         | Path on the server                     |
| --------------------------- | -------------------------------------- |
| `keycloak/db-password`      | `/run/secrets/keycloak-db-password`    |
| `keycloak/admin-password`   | `/run/secrets/keycloak-admin-password` |

## 1. DNS (do this first)

Create an `A` record for `keycloak.waynevanson.com` at the same address as
`waynevanson.com`. The name is part of the shared `waynevanson.com` ACME
certificate, so **a missing record makes renewal fail for every site on it**
(blog, S3, Jellyfin, WordPress), not just Keycloak.

## 2. Deploy

```sh
nix run .#server switch

curl -I https://keycloak.waynevanson.com
systemctl status keycloak.service keycloakPostgreSQLInit.service nginx.service
```

If the page does not load, check `journalctl -u keycloak -n 100` for the
database connection first: the role/database are only created once
`keycloakPostgreSQLInit` has run (it waits for `postgresql.target`).

## 3. First login

The `admin` user in the `master` realm is created on the first start with the
password from sops:

```sh
# on the server
sudo cat /run/secrets/keycloak-admin-password
```

Open <https://keycloak.waynevanson.com> and log in as `admin`. There is no
self-service recovery for `admin` from the UI, so change the password and add a
real email address under *Users -> admin* straight away.

`bootstrap-admin-password` is only read while the master realm has no users, so
leaving it in the config is harmless; it is also the fallback if the `admin`
account is ever lost (delete the master realm's users in the database and
restart to re-bootstrap).

## 4. Backups

The `keycloak` database is included in `services.postgresqlBackup`
(`/srv/data/backups/postgresql`, on the RAID array, daily zstd dumps). The
database — not `/var/lib/keycloak` — is the source of truth for realms, clients
and users. On a reinstall, restore the newest `keycloak.sql.zst` after
`postgresql` has started and before starting Keycloak.

## Recreating the database password

Rotating the password only needs a new `keycloak/db-password` in sops:

```sh
sops set .sops.secrets.yaml '["keycloak"]["db-password"]' '"<new-password>"'
sops updatekeys .sops.secrets.yaml
```

`keycloakPostgreSQLInit` only creates the role on first run; on an existing
install, apply the new password to the role manually (`ALTER ROLE keycloak
PASSWORD ...` as the `postgres` user) before switching, otherwise Keycloak will
fail to connect. The database password is not shown in the Keycloak admin
console, so treat this as the only place to rotate it.
