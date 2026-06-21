# Break down `hosts/server/default.nix` into modules

## Goal

Decompose the monolithic `hosts/server/default.nix` into focused per-concern modules, mirroring the pattern already used by the other imported host files (`forgejo.nix`, `zed.nix`, etc.). The resulting `default.nix` should only wire imports together.

## Context

- `hosts/server/default.nix` currently defines all configuration inside a single `let ... in` block with seven inline modules:
  - `acme'` — ACME certificate for `waynevanson.com` and subdomains.
  - `nginx'` — nginx base setup and firewall ports.
  - `atticd'` — Attic binary cache backed by Garage S3.
  - `garage'` — Garage S3-compatible object store.
  - `homeManager'` — home-manager activation for the `zed` user.
  - `host'` — base host configuration (boot, ZFS, networking, locale, users, sops, sshd).
- The flake passes `inputs`, `system`, and `self` as `specialArgs`, so extracted modules can reference them directly as module arguments.
- `self.nixosModules.sops` already defines `sops.defaultSopsFile` and all secret bindings (`spaceship-client-id`, `garage-access-key`, etc.), so `host'` redundantly repeats `sops.defaultSopsFile`. The refactor should remove that duplication while keeping host-specific sops settings (`age.sshKeyPaths`).
- Existing per-service files (`forgejo.nix`, `opencode.nix`, `zed.nix`, `minecraft.nix`, `wordpress-wayne.nix`) should remain untouched.

## Proposed file layout

```
hosts/server/
├── default.nix              # only imports
├── system.nix               # base host config (was host')
├── acme.nix                 # ACME certs (was acme')
├── nginx.nix                # nginx + firewall (was nginx')
├── atticd.nix               # Attic cache (was atticd')
├── garage.nix               # Garage S3 (was garage')
├── home-manager.nix         # home-manager for zed (was homeManager')
├── forgejo.nix              # existing
├── opencode.nix             # existing
├── zed.nix                  # existing
├── minecraft.nix            # existing
├── wordpress-wayne.nix      # existing
├── forgejo-runner.nix       # existing but commented out
├── wordpress-lx.nix         # existing but commented out
└── disko-configuration/     # existing
```

## Tasks

- [ ] Create `hosts/server/acme.nix` containing the current `acme'` module.
- [ ] Create `hosts/server/nginx.nix` containing the current `nginx'` module.
- [ ] Create `hosts/server/atticd.nix` containing the current `atticd'` module.
- [ ] Create `hosts/server/garage.nix` containing the current `garage'` module.
- [ ] Create `hosts/server/home-manager.nix` containing the current `homeManager'` module.
- [ ] Create `hosts/server/system.nix` containing the current `host'` module, but:
  - [ ] Remove the redundant `sops.defaultSopsFile` setting (already provided by `self.nixosModules.sops`).
  - [ ] Keep `sops.age.sshKeyPaths` because it is host-specific.
- [ ] Rewrite `hosts/server/default.nix` to import only:
  - `self.nixosModules.custom`
  - `inputs.nix-minecraft.nixosModules.minecraft-servers`
  - Existing `./forgejo.nix`, `./opencode.nix`, `./zed.nix`, `./minecraft.nix`, `./wordpress-wayne.nix`
  - New `./acme.nix`, `./nginx.nix`, `./atticd.nix`, `./garage.nix`, `./home-manager.nix`, `./system.nix`
  - `./disko-configuration`
- [ ] Verify the configuration evaluates with `nix flake check .` or by building the server configuration.

## Pending questions

1. Should `nginx.nix` and `acme.nix` be merged into a single `web.nix` or `tls.nix` because they are both shared web infrastructure, or kept separate for clarity?
2. Should `home-manager.nix` be merged into `zed.nix` since both concern the `zed` user, or kept separate because one is system-level and the other is home-manager?
3. Should the commented-out imports (`forgejo-runner.nix`, `wordpress-lx.nix`) be left commented in `default.nix` exactly as they are now?
