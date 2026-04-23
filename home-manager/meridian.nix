# home-manager config
{ config, lib, ... }:
{

  services.meridian = {
    enable = true;
    settings = {
      port = 3456;
      host = "127.0.0.1";
      # passthrough = true;
      defaultAgent = "opencode";
      # sonnetModel = "sonnet";
    };

    # Extra env vars not covered by settings
    environment = {
      PATH = lib.mkForce "/run/current-system/sw/bin:${config.home.profileDirectory}/bin:/usr/bin:/bin";
    };
  };

  home.sessionVariables = {
    ANTHROPIC_API_KEY = "x";
    ANTHROPIC_BASE_URL = "http://127.0.0.1:3456";
  };
}
