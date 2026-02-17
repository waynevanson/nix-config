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
          device = "/dev/disk/by-id/ata-CT240BX500SSD1_1906E1720EA1";
          content = {
            type = "gpt";
            partitions = {
              boot = {
                name = "boot";
                size = "1M";
                type = "EF02";
              };
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
        hdd-a = "/dev/disk/by-id/ata-WDC_WD20EZRZ-22Z5HB0_WD-WCC4M2KFNKPE";
        hdd-b = "/dev/disk/by-id/ata-WDC_WD20EZRZ-00Z5HB0_WD-WCC4M6AT08AF";
        hdd-c = "/dev/disk/by-id/ata-WDC_WD20EZRZ-22Z5HB0_WD-WCC4M3XHJ9TJ";
      };

    zpool = {
      zmain = {
        type = "zpool";
        mode = "raidz1";
      };
    };
  };
}
