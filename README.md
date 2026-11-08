## Todo

1. Use stable nixos release instead of unstable.
2. Add jelllyfin.

## USB

These instructions are for me, I hold no liability for you.

1. Create the hybrid ISO image.

```sh
nix build .#bootable
```

The image is at `result/iso/*.iso`. It boots on both BIOS and UEFI machines and can be written directly to a USB stick.

2. Find the USB device (check carefully, this wipes it).

```sh
lsblk -o NAME,SIZE,MODEL,TRAN
```

3. Write the image to the USB.

```sh
# Replace /dev/sdX with the USB device, NOT a partition like /dev/sdX1.
sudo dd if=./result/iso/*.iso of=/dev/sdX bs=4M conv=fsync status=progress
sudo sync
```

4. Plug the USB into the target machine, boot it, and wait for the login prompt.

The image has DHCP enabled on all wired interfaces. Find the address it got from
the router, or log in on the console as `root` (no password locally) and run:

```sh
ip -4 addr show scope global
```

5. Verify the current machine can reach it and that nixos-anywhere's key is accepted:

```sh
ssh -i ~/.ssh/id_ed25519 root@<TARGET_IP> true
```

## Overwrite an existing server from USB

Use this when the target has been booted from the USB image and you want to
wipe and reinstall it. It generates (or reuses) a server host key in the
gitignored `.secrets/server/` directory, updates the sops recipient, re-encrypts
the secrets, and runs `nixos-anywhere` with the host key included in the new
root filesystem.

```sh
nix run .#server-overwrite -- root@<TARGET_IP>
```

The optional second argument is the SSH identity used to connect to the USB
installer (defaults to `~/.ssh/id_ed25519`). Do not delete `.secrets/server/`
unless you intend to rotate the server host key and sops recipients.

## Install via `nixos-anywhere`

1. Install the server configuration over SSH. This partitions the target disks
   according to `hosts/server/disko-configuration` and installs the flake.

```sh
nix run github:nix-community/nixos-anywhere -- \
  --flake .#server \
  --target-host root@<TARGET_IP> \
  -i ~/.ssh/id_ed25519
```

If the target is new hardware, generate its hardware report first instead of
reusing `hosts/server/facter.json`, and update the disk `device` paths in
`hosts/server/disko-configuration` to match the new machine:

```sh
nix run github:nix-community/nixos-anywhere -- \
  --flake .#server \
  --target-host root@<TARGET_IP> \
  -i ~/.ssh/id_ed25519 \
  --generate-hardware-config nixos-facter hosts/server/facter.json
```

2. When successful, remove USB and reboot.

3. SSH

```sh
ssh waynevanson@<TARGET_IP> -p 8022
```

## Updates

Probably just the same command as before but without the hardware config and find a way to ensure disko doesn't format. I don't think it would with existing machines.
