{
  config,
  lib,
  pkgs,
  ...
}: let
   config' = config.custom.virtualisation.containerd;
in {
  options.custom.virtualisation.containerd.enable = lib.mkEnableOption {};

  config = lib.mkIf config'.enable {
    virtualisation.containerd.enable = true;

    # Optional: Enable default CNI plugins
    virtualisation.containerd.settings = {
      plugins."io.containerd.grpc.v1.cri".cni = {
        bin_dir = "${pkgs.cni-plugins}/bin";
        conf_dir = "/etc/cni/net.d";
      };
    };

    environment.systemPackages = with pkgs; [
      nerdctl
    ];
  };
}
