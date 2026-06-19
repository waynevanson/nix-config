# Add OpenCode server to NixOS server host

Created: 2026-06-19T05:50:42Z

## Goal

Add the OpenCode server (`opencode serve`) from `anomalyco/opencode` as a systemd service on the `hosts/server` NixOS host, exposed behind nginx on `opencode.waynevanson.com`, using sops for the server password.

## Context

- The target repo is `https://github.com/anomalyco/opencode` (default branch `dev`).
- That flake provides packages and an overlay but **no NixOS module**.
- The package is also available in nixpkgs as `pkgs.opencode` (confirmed present in the current flake pin as `opencode-1.17.7`). This plan uses the nixpkgs package since there is no `opencode` flake input.
- The server is started with `opencode serve` and accepts `--port`, `--hostname`, `--mdns`, and `--cors` options.
- Authentication is controlled by the `OPENCODE_SERVER_PASSWORD` environment variable (a warning is printed if unset).
- The server binds to `127.0.0.1:4096` by default and uses HTTP/WebSockets.
- Existing server services in this repo are added as host-specific modules under `hosts/server/` and reuse the shared nginx/ACME/sops setup.

## Tasks

- [ ] Task 1: Create `modules/custom/services/opencode.nix`
  - Define `options.custom.services.opencode.server` with settings for:
    - `enable`
    - `package` (default `pkgs.opencode`)
    - `port` (default `4096`)
    - `hostname` (default `127.0.0.1`)
    - `passwordFile`
    - `mdns` (default `false`)
    - `cors` (default `[]`)
    - `nginx.enable` (default `true`)
    - `nginx.hostName` (default `opencode.waynevanson.com`)
  - Create `opencode` system user/group.
  - Add a `systemd.services.opencode-server` unit that:
    - Runs `opencode serve --port 4096 --hostname 127.0.0.1`
    - Loads `OPENCODE_SERVER_PASSWORD` from `passwordFile`
    - Sets `HOME=/var/lib/opencode` and uses `StateDirectory = "opencode"`
  - Add an nginx virtual host for the configured subdomain with WebSocket proxying.

- [ ] Task 2: Register the new module in `modules/custom/services/default.nix`
  - Add `./opencode.nix` to the `imports` list.

- [ ] Task 3: Create `hosts/server/opencode.nix`
  - Enable the service:
    ```nix
    {
      custom.services.opencode.server = {
        enable = true;
        passwordFile = config.sops.secrets.opencode-server-password.path;
      };
    }
    ```

- [ ] Task 4: Update `hosts/server/default.nix`
  - Add `./opencode.nix` to the `imports` list.
  - Add `opencode.waynevanson.com` to `security.acme.certs."waynevanson.com".extraDomainNames`.
  - Add `opencode.waynevanson.com` to `networking.extraHosts`.

- [ ] Task 5: Update `modules/sops.nix`
  - Add `opencode-server-password.key = "opencode/server-password";` to the `sops.secrets` set.

- [ ] Task 6: Add placeholder secret to `.sops.secrets.yaml`
  - Add the key `opencode/server-password` with value `PLACEHOLDER_SET_ME`.
  - Re-encrypt with sops.

- [ ] Task 7: Set the real password
  - User edits `.sops.secrets.yaml` (e.g. via `sops .sops.secrets.yaml`) and replaces `PLACEHOLDER_SET_ME` with the actual `OPENCODE_SERVER_PASSWORD`.

- [ ] Task 8: Build and switch
  - Run `nix run .#server build` to verify the configuration evaluates.
  - Run `nix run .#server switch` to deploy.

## Pending Questions

- None. Subdomain (`opencode.waynevanson.com`), port (`4096`), sops-managed password, and dedicated `opencode` user have been confirmed.
