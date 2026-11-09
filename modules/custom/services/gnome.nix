{
  config,
  lib,
  ...
}:
let
  config' = config.custom.services.gnome;
in
{
  options.custom.services.gnome = {
    enable = lib.mkEnableOption { };
  };
  config = lib.mkIf config'.enable {
    services = {
      desktopManager.gnome.enable = true;
      displayManager.gdm = {
        enable = true;
        # Keep the machine awake when nobody is signed in. Suspending here
        # would also cut off SSH sessions.
        autoSuspend = false;
      };
      pulseaudio.enable = false;
      pipewire = {
        enable = true;
        alsa = {
          enable = true;
          support32Bit = true;
        };
        pulse.enable = true;
        # If you want to use JACK applications, uncomment this
        #jack.enable = true;
      };
      # Enable touchpad support (enabled default in most desktopManager).
      libinput.enable = true;
      # GNOME runs Wayland by default. Enable the X server if you need the
      # X11 session or X11-only tooling.
      # xserver.enable = true;
    };
    security.rtkit.enable = true;
    fonts.fontconfig.enable = true;
  };
}
