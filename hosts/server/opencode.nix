{
  security.acme.certs."waynevanson.com".extraDomainNames = [ "opencode.waynevanson.com" ];

  custom.services.opencode.server = {
    enable = true;
  };
}
