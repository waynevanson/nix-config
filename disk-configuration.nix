# We kind of want a similar setup to truenas.
# 1 drive for OS and other stuff defined in the system
# then the rest in ZFS RAIDZ for data and applications
{
  inputs,
  lib,
  ...
}: let
  createDiskZfs = {device}: {
    inherit device;
    type = "disk";
    content = {
      type = "gpt";
      partitions = {
        zfs = {
          size = "100%";
          content = {
            type = "zfs";
            pool = "zmain";
          };
        };
      };
    };
  };
  createDisksZfs = builtins.mapAttrs (
    _: device: createDiskZfs {inherit device;}
  );
in {
  imports = [
    inputs.disko.nixosModules.default
  ];

  disko.devices = {
    disk =
      {
        ssd-a = {
          type = "disk";
          device = "/dev/disk/by-uuid/?";
          content = {
            type = "gpt";
            partitions = {
              ESP = {
                size = "64M";
                type = "EF00";
                content = {
                  type = "filesystem";
                  format = "vfat";
                  mountpoint = "/boot";
                  mountOptions = ["umask=0077"];
                };
              };
              root = {
                size = "100%";
                content = {
                  type = "filesystem";
                  format = "ext4";
                  mountpoint = "/";
                };
              };
            };
          };
        };
      }
      // createDisksZfs {
        hdd-a = "/dev/disk/by-uuid/?";
        hdd-b = "/dev/disk/by-uuid/?";
        hdd-c = "/dev/disk/by-uuid/?";
      };

    zpool = {
      zmain = {
        type = "zpool";
        mode = "raidz1";
      };
    };
  };
}
