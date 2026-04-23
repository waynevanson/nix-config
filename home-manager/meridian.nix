# home-manager config
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
    # environment = {
    #   MERIDIAN_MAX_CONCURRENT = "20";
    # };
  };
}
