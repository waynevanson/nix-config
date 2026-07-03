{
  config,
  ...
}:
{
  security.acme = {
    acceptTerms = true;
    defaults.email = "waynevanson@gmail.com";
    certs."waynevanson.com" = {
      group = "nginx";
      dnsProvider = "spaceship";
      webroot = null;
      credentialFiles = {
        "SPACESHIP_API_KEY_FILE" = config.sops.secrets.spaceship-client-id.path;
        "SPACESHIP_API_SECRET_FILE" = config.sops.secrets.spaceship-client-secret.path;
      };
    };
  };

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];
}
