{
  security.acme.certs."waynevanson.com".extraDomainNames = [ "headscale.waynevanson.com" ];

  services.headscale = {
    enable = true;

    settings = {
      server_url = "https://headscale.waynevanson.com";

      dns = {
        magic_dns = true;
        base_domain = "tailnet.waynevanson.com";
        nameservers.global = [
          "1.1.1.1"
          "8.8.8.8"
        ];
      };
    };
  };

  services.nginx.virtualHosts."headscale.waynevanson.com" = {
    useACMEHost = "waynevanson.com";
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:8080";
      proxyWebsockets = true;
      recommendedProxySettings = true;
    };
  };
}
