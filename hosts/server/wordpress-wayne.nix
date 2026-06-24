{ config, ... }:
{
  sops.secrets.digitalocean-token = {
    key = "digitalocean/token";
  };
  custom.services.wordpress.instances."waynevanson.com" = {
    acmeHost = "waynevanson.com";
  };
  networking.extraHosts = ''
    127.0.0.1 waynevanson.com
    127.0.0.1 www.waynevanson.com
  '';
}
