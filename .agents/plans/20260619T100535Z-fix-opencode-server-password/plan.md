# Fix opencode server password authentication

Created: 2026-06-19T10:05:35Z

## Goal

Make `opencode-remote` and the web UI at `opencode.waynevanson.com` authenticate successfully against the opencode server by provisioning the sops-managed password into the file opencode actually reads, and by ensuring no trailing newline sneaks into the password.

## Context

The current NixOS module (`modules/custom/services/opencode.nix`) starts the server with:

```nix
systemd.services.opencode-server = {
  serviceConfig = {
    EnvironmentFile = config.sops.templates.opencode-environment-file.path;
    Environment = [ "HOME=/var/lib/opencode" ];
    ExecStart = "${cfg.package}/bin/opencode ${escapeShellArgs args}";
  };
};
```

where the environment file sets `OPENCODE_SERVER_PASSWORD`. However, in opencode v1.17.7 the `serve` handler does **not** read that env var. It calls `daemon.password()`, which reads the password from opencode's state directory (`~/.local/state/opencode/password`, i.e. `/var/lib/opencode/.local/state/opencode/password` with `HOME=/var/lib/opencode`). If that file is missing it generates a random password. The env var is therefore ignored and the server ends up with a different password than the one in sops, which breaks both `opencode-remote` and the web login.

The client wrapper (`home-manager/opencode/default.nix`) also reads the secret with `$(cat ...)`, which will include a trailing newline if the sops secret was created with one (e.g. `echo "password"`). That breaks manual password entry on the website even when the server and client do share the same secret.

References:
- `modules/custom/services/opencode.nix`
- `home-manager/opencode/default.nix`
- `modules/sops.nix`
- opencode v1.17.7 source: `packages/cli/src/commands/handlers/serve.ts`, `packages/cli/src/services/daemon.ts`, `packages/server/src/auth.ts`

## Tasks

- [x] Task 1: Confirm the exact daemon password path
  - With `HOME=/var/lib/opencode`, opencode uses `$HOME/.local/state/opencode/password`.

- [x] Task 2: Update `modules/custom/services/opencode.nix`
  - Removed the unused `sops.templates.opencode-environment-file` block and `EnvironmentFile` reference.
  - Added `ExecStartPre` that writes the sops secret to `/var/lib/opencode/.local/state/opencode/password` with trailing newlines stripped.

- [x] Task 3: Update `home-manager/opencode/default.nix`
  - `OPENCODE_SERVER_PASSWORD` now strips trailing newlines before exporting.

- [x] Task 4: Decide whether to keep `OPENCODE_SERVER_PASSWORD` in the server env
  - Removed from the server; kept in the client wrapper where `opencode attach` uses it for the `Authorization` header.

- [ ] Task 5: Rebuild and deploy
  - Run `nixos-rebuild switch` on `hosts/server`.
  - Restart `opencode-server.service` if it does not restart automatically.

- [ ] Task 6: Test
  - Run `opencode-remote` from a client machine and confirm it connects without prompting for a password.
  - Visit `https://opencode.waynevanson.com` in a browser, enter the password exactly as stored in sops (without any trailing newline), and confirm login succeeds.

## Pending Questions

- Should the sops secret itself be rewritten to contain no trailing newline, or is stripping at read/write time sufficient? Stripping at read/write time is safer and does not require re-encrypting the secret.
- Is it acceptable to remove `sops.templates.opencode-environment-file` entirely, or is it relied upon elsewhere? If another module references it, keep it but remove the `EnvironmentFile` line from the opencode service.
- Do we want to set `XDG_STATE_HOME=/var/lib/opencode/state` to make the password path shorter and more explicit, or keep the default `~/.local/state/opencode` path?
