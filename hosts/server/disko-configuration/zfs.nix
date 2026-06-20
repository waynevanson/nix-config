{
  hardware.facter.reportPath = ./facter.json;

  disko.devices = {
    disk = {
      wdc1 = {
        type = "disk";
        device = "/dev/disk/by-id/ata-WDC_WD20EZRZ-00Z5HB0_WD-WCC4M6AT08AF";
        content = {
          type = "gpt";
          partitions.zfs = {
            size = "100%";
            content = {
              type = "zfs";
              pool = "tank";
            };
          };
        };
      };

      wdc2 = {
        type = "disk";
        device = "/dev/disk/by-id/ata-WDC_WD20EZRZ-22Z5HB0_WD-WCC4M2KFNKPE";
        content = {
          type = "gpt";
          partitions.zfs = {
            size = "100%";
            content = {
              type = "zfs";
              pool = "tank";
            };
          };
        };
      };

      wdc3 = {
        type = "disk";
        device = "/dev/disk/by-id/ata-WDC_WD20EZRZ-22Z5HB0_WD-WCC4M3XHJ9TJ";
        content = {
          type = "gpt";
          partitions.zfs = {
            size = "100%";
            content = {
              type = "zfs";
              pool = "tank";
            };
          };
        };
      };
    };

    zpool = {
      tank = {
        type = "zpool";
        mode = "raidz";
        options = {
          ashift = "12";
        };
        rootFsOptions = {
          compression = "zstd";
          atime = "off";
        };
        mountpoint = "/srv/data";
      };
    };
  };
}
