# bind the local sops secrets so they can be reused
# We share all secrets across all systems so all good
{ ... }:
{
  options = { };
  config = {
    sops.defaultSopsFile = ../.sops.secrets.yaml;
    sops.secrets = {
      spaceship-client-id.key = "spaceship/client-id";
      spaceship-client-secret.key = "spaceship/client-secret";
      atticd-secret.key = "atticd/secret";
      garage-rpc-secret.key = "garage/rpc-secret";
      garage-access-key.key = "garage/access-key";
      garage-secret-key.key = "garage/secret-key";
      postgres-password.key = "postgres/password";
    };
  };
}
