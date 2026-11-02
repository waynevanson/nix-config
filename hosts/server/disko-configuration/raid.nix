{ lib, ... }:
let
  disks = {
    hdd1 = "ata-WDC_WD20EZRZ-00Z5HB0_WD-WCC4M6AT08AF";
    hdd2 = "ata-WDC_WD20EZRZ-22Z5HB0_WD-WCC4M2KFNKPE";
    hdd3 = "ata-WDC_WD20EZRZ-22Z5HB0_WD-WCC4M3XHJ9TJ";
  };
in
{
  disko.devices = {
    disk = lib.mapAttrs (_name: diskId: {
      type = "disk";
      device = "/dev/disk/by-id/${diskId}";
      content = {
        type = "gpt";
        partitions.primary = {
          name = "primary";
          size = "100%";
          content = {
            type = "lvm_pv";
            vg = "storage";
          };
        };
      };
    }) disks;

    lvm_vg.storage = {
      type = "lvm_vg";
      lvs.data = {
        name = "data";
        size = "100%FREE";
        lvm_type = "raid5";
        # Three disks: two data stripes and one parity stripe.
        extraArgs = [ "--stripes=2" ];
        content = {
          type = "filesystem";
          format = "ext4";
          mountpoint = "/srv/data";
          mountOptions = [
            "defaults"
            "noatime"
          ];
        };
      };
    };
  };
}
