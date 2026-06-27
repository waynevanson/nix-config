# Setup required so we can spawn containers however we want.
{
  pkgs,
  ...
}:
{
  # Forward interfaces created from containers to the host.
  networking.nat = {
    enable = true;
    internalInterfaces = [ "ve-+" ];
    externalInterface = "ens3";
    enableIPv6 = true;
  };

  environment.systemPackages = with pkgs; [ nixos-container ];

  # Workflow for expected usage.
  # Project pushes to container. Container available at `procurare.waynevanson.com`
  # Project contains multiple containers in a container with it's own network.
  # Port forward to host 5130

  # Workflow for dynamic usage.
  # Projects push to the container. Container available at `*.container.waynevanson.com`
}
