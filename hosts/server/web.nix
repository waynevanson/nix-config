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
      extraDomainNames = [
        "runner.git.waynevanson.com"
        "zed.waynevanson.com"
        "minecraft.waynevanson.com"
      ];
      dnsProvider = "spaceship";
      webroot = null;

      credentialFiles = {
        "SPACESHIP_API_KEY_FILE" = config.sops.secrets.spaceship-client-id.path;
        "SPACESHIP_API_SECRET_FILE" = config.sops.secrets.spaceship-client-secret.path;
      };
    };
  };

  services.nginx = {
    enable = true;
    virtualHosts = { };
  };

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];
}
