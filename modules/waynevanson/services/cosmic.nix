{
  config,
  lib,
  ...
}: let
  config' = config.waynevanson.services.cosmic;
in {
  options.waynevanson.services.cosmic = {
    enable = lib.mkEnableOption {};
  };

  config =
    lib.mkIf config'.enable
    {
      services.desktopManager.cosmic.enable = true;
      services.displayManager.cosmic-greeter.enable = true;
      services.system76-scheduler.enable = true;

      # clipboard - security bypass
      environment.sessionVariables.COSMIC_DATA_CONTROL_ENABLED = 1;

      programs.firefox.preferences = {
        # disable libadwaita theming for Firefox
        "widget.gtk.libadwaita-colors.enabled" = false;
      };

      services.pulseaudio.enable = false;
      security.rtkit.enable = true;
      services.pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        pulse.enable = true;
        # If you want to use JACK applications, uncomment this
        #jack.enable = true;

        # use the example session manager (no others are packaged yet so this is enabled by default,
        # no need to redefine it in your config for now)
        #media-session.enable = true;
      };

      # Enable touchpad support (enabled default in most desktopManager).
      services.libinput.enable = true;

      fonts.fontconfig.enable = true;
    };
}
