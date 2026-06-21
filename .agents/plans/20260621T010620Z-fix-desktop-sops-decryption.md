# Fix desktop NixOS switch failing on sops-nix decryption

## Goal

Make `nixos-rebuild switch` succeed on the desktop host by ensuring sops-nix can decrypt `.sops.secrets.yaml` with the keys available on that machine.

## Context

The failure was:

```text
sops-install-secrets: failed to decrypt '/nix/store/...-.sops.secrets.yaml': Error getting data key: 0 successful groups required, got 0
```

- Commit `d4610fa` (`feat(attic-client): add watch-store module and enable on desktop/server`) made the desktop start using the shared `self.nixosModules.sops` module and the `attic-client-token` system secret.
- That shared module configured `age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];`, which is only appropriate for the server.
- The desktop does not have its SSH host key in `.sops.yaml`, so it could not decrypt.
- The server decrypts with its SSH host key (`server_homelab`), and the desktop user/Home Manager already decrypts with the admin age key at `/home/waynevanson/.config/sops/age/keys.txt`.

## Implemented fix

- `modules/sops.nix`: removed the shared `age.sshKeyPaths` setting.
- `hosts/server/default.nix`: added `sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];` back as a server-only setting.
- `hosts/desktop/default.nix`: added `sops.age.keyFile = "/home/waynevanson/.config/sops/age/keys.txt";` so desktop system activation uses the existing admin/user age key.

## Verification

- [x] `nixos-rebuild build --flake .#nixos` succeeds.
- [x] `nixos-rebuild build --flake .#server` succeeds.
- [ ] `sudo nixos-rebuild switch --flake .` on the desktop (could not run inside this sandbox because `sudo` is blocked).

## Notes

- No changes to `.sops.yaml` or `.sops.secrets.yaml` were needed.
- The desktop system activation now reads the same age key file that Home Manager already uses.
