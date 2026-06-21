# Fix desktop NixOS switch failing on sops-nix decryption

## Goal

Make `nixos-rebuild switch` succeed on the desktop host by ensuring sops-nix can decrypt `.sops.secrets.yaml` with the keys available on that machine.

## Context

The failure is:

```text
sops-install-secrets: failed to decrypt '/nix/store/...-.sops.secrets.yaml': Error getting data key: 0 successful groups required, got 0
```

- `modules/sops.nix` is shared by both `server` and `desktop` and configures:
  - `age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];`
- On the desktop, sops-install-secrets converted that host key to the age public key `age10h32a9e4nxmqzgtrp44wjzyw9gz6zlkzgdye97asj2j3nk2zmewsn9gu77`.
- `.sops.yaml` currently only lists these age recipients:
  - `admin_waynevanson` (`age1qssg5g2jkt9n68lq4hyjmr56uucnanckkvseecyanzflmyalpu3s2ss4g9`)
  - `server_homelab` (`age1kq8slysaa6pndupg3z4gkypt9ul94lmdpg2q5ky28swms6jhuakq2qfjfy`)
- Because the desktop's host key is not a recipient, decryption fails during activation.
- The admin age secret key exists locally at `/home/waynevanson/.config/sops/age/keys.txt`, so we can re-encrypt the secrets file after adding the new recipient.

## Tasks

- [ ] 1. Confirm the desktop's host age recipient
  - On the desktop run:
    ```bash
    ssh-to-age -i /etc/ssh/ssh_host_ed25519_key.pub
    ```
  - It should match `age10h32a9e4nxmqzgtrp44wjzyw9gz6zlkzgdye97asj2j3nk2zmewsn9gu77` from the error output.

- [ ] 2. Add the desktop key to `.sops.yaml`
  - Add a new alias under `keys`, e.g. `desktop_nixos`.
  - Include that alias in the `key_groups` for the `^.sops.secrets.yaml$` creation rule.
  - Example diff shape:
    ```yaml
    keys:
      - &admin_waynevanson age1qssg5g2jkt9n68lq4hyjmr56uucnanckkvseecyanzflmyalpu3s2ss4g9
      - &server_homelab age1kq8slysaa6pndupg3z4gkypt9ul94lmdpg2q5ky28swms6jhuakq2qfjfy
      - &desktop_nixos age10h32a9e4nxmqzgtrp44wjzyw9gz6zlkzgdye97asj2j3nk2zmewsn9gu77
    creation_rules:
      - path_regexp: ^.sops.secrets.yaml$
        key_groups:
          - age:
              - *admin_waynevanson
              - *server_homelab
              - *desktop_nixos
    ```

- [ ] 3. Re-encrypt `.sops.secrets.yaml`
  - Use the existing admin age key to update the data-key encryption:
    ```bash
    SOPS_AGE_KEY_FILE=/home/waynevanson/.config/sops/age/keys.txt \
      sops updatekeys -y .sops.secrets.yaml
    ```
  - This should add a new `sops.age` recipient entry for `desktop_nixos` without changing any plaintext secrets.

- [ ] 4. Verify the diff
  - Check `git diff .sops.yaml .sops.secrets.yaml`.
  - Expect only:
    - the new key alias and recipient entry,
    - updated `lastmodified` / `mac` metadata.
  - No plaintext secrets should change.

- [ ] 5. Test the fix
  - Run a rebuild to confirm activation no longer fails:
    ```bash
    sudo nixos-rebuild test --flake .
    ```
  - If successful, run the real switch:
    ```bash
    sudo nixos-rebuild switch --flake .
    ```

- [ ] 6. Commit the changes
  - Commit the updated `.sops.yaml` and `.sops.secrets.yaml`.

## Pending questions

1. **Host-key vs. admin-key binding:** Adding the desktop's SSH host-derived age key keeps the same model already used for `server_homelab`. This means a host reinstall/regenerated SSH key would require re-encrypting secrets. Are you happy with that, or would you prefer the desktop system secrets to use your existing admin/user age key file instead?
2. **Public key confirmation:** Is the age public key `age10h32a9e4nxmqzgtrp44wjzyw9gz6zlkzgdye97asj2j3nk2zmewsn9gu77` from the switch output the correct one for this desktop, or has the host key changed since that error?
