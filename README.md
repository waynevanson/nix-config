## TODO

1. Create commands that can be run via `nix run .#install-homelab`.

## USB

These instructions are for me, I hold no liability for you.

1. Create the image.

```sh
nix build .#bootable
```

2. Write the image to a USB.

```sh
sudo dd if=/dev/sda of=./result/iso/*.iso conv=fsync status=progress
```

3. Plug into server computer, boot into USB and wait 3 minutes.

## Install via `nixos-anywhere`

1. Install the homelab configuration via SSH.

```sh
nix run github:nix-community/nixos-anywhere -- --flake .#homelab  --target-host root@192.168.1.103 -i ~/.ssh/id_ed25519 --generate-hardware-config nixos-facter hosts/homelab/facter.json
```

2. When successful, remove USB and reboot.

3. SSH

```sh
ssh waynevanson@192.168.1.103 -p 8022
```

## Updates

Probably just the same command as before but without the hardware config and find a way to ensure disko doesn't format. I don't think it would with existing machines.
