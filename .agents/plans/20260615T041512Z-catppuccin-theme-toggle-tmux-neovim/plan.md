# Catppuccin Dark/Light Theme Toggle for Writer Host

Created: 2026-06-15T04:15:12Z

## Goal

Make the Catppuccin theme togglable at runtime for tmux and Neovim on the `writer` host only, switching between `latte` (light) and `mocha` (dark), with live updates to running Neovim instances.

## Context

- File in scope: `hosts/writer/default.nix`
- Current setup:
  - `programs.neovim` is enabled system-wide with `catppuccin-nvim` and `flavour = "mocha"`
  - `programs.tmux` is enabled system-wide with the `catppuccin` plugin and `set -g @catppuccin_flavor "mocha"`
- Theme state will be stored in `~/.config/catppuccin-theme` with contents `mocha` or `latte`
- Both tmux (`prefix + T`) and Neovim (`:ToggleCatppuccin`) will be able to initiate a toggle
- Live Neovim updates use RPC sockets at `/tmp/nvim-<pid>`

## Tasks

- [ ] **Task 1: Add `config` argument to module header**
  - Change `{ pkgs, ... }:` to `{ pkgs, config, ... }:` in `hosts/writer/default.nix`
  - `config` is not strictly required for the final implementation but keeps the module extensible if home-directory paths are needed later

- [ ] **Task 2: Define theme state path and toggle script**
  - In the `let` block, add:
    - `themeFile = "$HOME/.config/catppuccin-theme";`
    - `toggleThemeScript = pkgs.writeShellScriptBin "toggle-catppuccin-theme" ''...'';`
  - Script behaviour:
    1. Read current value from `~/.config/catppuccin-theme`, defaulting to `mocha`
    2. Flip to the opposite flavour
    3. Write the new value back
    4. If running inside tmux, update `@catppuccin_flavor` and `source-file /etc/tmux.conf`
    5. Broadcast the new flavour to every `/tmp/nvim-*` socket via `nvim --server <socket> --remote-send ":lua _G.apply_catppuccin_theme(\"<flavour>\")<CR>"`

- [ ] **Task 3: Add toggle script to system packages**
  - Add `toggleThemeScript` to `environment.systemPackages` so it is available in `$PATH`

- [ ] **Task 4: Update Neovim configuration for theme switching**
  - Replace the existing `programs.neovim.configure.luaRcContent` with Lua that:
    1. Reads `~/.config/catppuccin-theme` on startup
    2. Defines `_G.apply_catppuccin_theme(flavour)` to call `require("catppuccin").setup({ flavour = ... })` and `vim.cmd.colorscheme("catppuccin")`
    3. Applies the saved flavour on startup
    4. Starts an RPC server socket at `/tmp/nvim-<pid>` with `vim.fn.serverstart(...)`
    5. Defines a local `toggle_catppuccin_theme()` function that:
       - Writes the new flavour to the state file
       - Updates tmux (`set-option -g @catppuccin_flavor` and `source-file /etc/tmux.conf`) when `vim.env.TMUX` is present
       - Broadcasts the new flavour to every other `/tmp/nvim-*` socket
       - Applies the new flavour locally
    6. Registers the user command `:ToggleCatppuccin`

- [ ] **Task 5: Update tmux configuration for theme switching**
  - In `programs.tmux`:
    - Set `baseIndex`, `keyMode`, etc. as desired (currently only `keyMode = "vi"` and `plugins` are set)
    - Add `extraConfigBeforePlugins` to set the flavour before the catppuccin plugin loads:
      ```tmux
      run-shell 'tmux set -g @catppuccin_flavor "$(cat ~/.config/catppuccin-theme 2>/dev/null || echo mocha)"'
      ```
    - Add `extraConfig` to bind `prefix + T`:
      ```tmux
      bind T run-shell "toggle-catppuccin-theme"
      ```

- [ ] **Task 6: Build and switch the configuration**
  - Run `sudo nixos-rebuild switch --flake .#writer` (or the equivalent flake target for the writer host)
  - Verify the build succeeds

- [ ] **Task 7: Test tmux toggle**
  - Start a new tmux session
  - Observe the status bar is in `mocha`
  - Press `prefix + T` (default prefix is `C-b`, so `C-b T`)
  - Verify the status bar switches to `latte`
  - Press `prefix + T` again and verify it switches back to `mocha`

- [ ] **Task 8: Test Neovim toggle**
  - Inside tmux, run `nvim`
  - Verify the colours match the current theme
  - Run `:ToggleCatppuccin`
  - Verify Neovim switches to the opposite flavour and tmux updates too
  - Open a second Neovim instance in another pane
  - Toggle in one instance and verify the other instance updates live

- [ ] **Task 9: Test persistence across new instances**
  - Set the theme to `latte` via either toggle
  - Quit all tmux and Neovim instances
  - Start a fresh tmux session and Neovim
  - Verify both start in `latte`

## Pending Questions

- Should the default prefix remain `C-b`? If the prefix is changed elsewhere, the `prefix + T` binding will follow the configured prefix automatically.
- Is it acceptable for the first toggle to create `~/.config/catppuccin-theme`? The initial default is inferred when the file is missing.
- Should the toggle also update the alacritty terminal theme? The user explicitly limited scope to tmux and Neovim, so alacritty is out of scope.
