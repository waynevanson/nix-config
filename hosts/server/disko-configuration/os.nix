{
  hardware.facter.reportPath = ./facter.json;

  disko.devices = {
    disk = {
      disk1 = {
        device = "/dev/disk/by-id/ata-CT240BX500SSD1_1906E1720EA1";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            boot = {
              name = "boot";
              size = "10M";
              type = "EF02";
            };
            esp = {
              name = "ESP";
              size = "500M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
              };
            };
            root = {
              name = "root";
              size = "100%";
              content = {
                type = "lvm_pv";
                vg = "pool";
              };
            };
          };
        };
      };

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

    lvm_vg = {
      pool = {
        type = "lvm_vg";
        lvs = {
          root = {
            size = "100%FREE";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/";
              mountOptions = [
                "defaults"
              ];
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
