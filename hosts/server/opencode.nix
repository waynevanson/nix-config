{ config, ... }:
{
  custom.services.opencode.server = {
    enable = true;
    passwordFile = config.sops.secrets.opencode-server-password.path;
  };
}
