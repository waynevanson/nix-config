{ lib, ... }:
let
  pool = "tank";
  createZfsDisks = lib.mapAttrs (
    diskName: diskId: {
      device = "/dev/disk/by-id/${diskId}";
      type = "disk";
      content = {
        type = "gpt";
        partitions.zfs = {
          size = "100%";
          content = {
            type = "zfs";
            inherit pool;
          };
        };
      };
    }
  );
in
{
  hardware.facter.reportPath = ./facter.json;
  disko.devices = {
    disk = createZfsDisks {
      wdc1 = "ata-WDC_WD20EZRZ-00Z5HB0_WD-WCC4M6AT08AF";
      wdc2 = "ata-WDC_WD20EZRZ-22Z5HB0_WD-WCC4M2KFNKPE";
      wdc3 = "ata-WDC_WD20EZRZ-22Z5HB0_WD-WCC4M3XHJ9TJ";
    };
    zpool = {
      ${pool} = {
        type = "zpool";
        mode = "raidz";
        options = {
          ashift = "12";
        };
        rootFsOptions = {
          compression = "zstd";
          atime = "off";
        };
        mountpoint = "/srv/tank";
        preMountHook = ''
          zpool list "tank" >/dev/null 2>/dev/null ||
            zpool import -f -l -R /mnt "tank"
        '';
      };
    };
  };
}
