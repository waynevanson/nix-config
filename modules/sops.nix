# bind the local sops secrets so they can be reused
# We share all secrets across all systems so all good
{ lib, ... }:
{
  services.openssh.enable = true;
  sops = {
    defaultSopsFile = ../.sops.secrets.yaml;
    age.sshKeyPaths = lib.mkDefault [ ];
    secrets = {
      spaceship-client-id.key = "spaceship/client-id";
      spaceship-client-secret.key = "spaceship/client-secret";
      atticd-secret.key = "atticd/secret";
      attic-client-token.key = "attic-client/token";
      garage-rpc-secret.key = "garage/rpc-secret";
      garage-access-key.key = "garage/access-key";
      garage-secret-key.key = "garage/secret-key";
      digitalocean-token.key = "digitalocean/token";
      postgres-juicefs-password.key = "postgres/juicefs-password";
      keycloak-db-password.key = "keycloak/db-password";
      keycloak-admin-password.key = "keycloak/admin-password";
      # Reusable pre-auth key, only used by hosts that opt into automatic
      # enrolment (`custom.services.headscale-client.authKeyFile`). Headscale
      # mints it during activation (`headscale-bootstrap.service`,
      # hosts/server/headscale.nix) and keeps it at
      # /var/lib/headscale/preauth-key on the server; `nix run
      # .#headscale-preauth-key` copies it here. Nothing reads it by default, and
      # the server itself never does — it uses the key it generated.
      headscale-preauth-key.key = "headscale/preauth-key";
    };
  };
}
