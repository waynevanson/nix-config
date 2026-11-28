# Global Rust compilation cache (sccache).
#
# `RUSTC_WRAPPER` is exported from the Home Manager session, so every `cargo`
# invocation in every project on this machine (bare shells, `nix develop`
# shells, editor-spawned tasks, `cargo install`) routes rustc through one shared
# on-disk cache in ~/.cache/sccache. Because crates.io sources live at the same
# ~/.cargo/registry path for every project, a dependency compiled once is reused
# by the next project instead of being rebuilt per target directory.
#
# Only the cache is configured here. No toolchain, cargo registry mirror or
# other Rust setup is touched: each project still brings its own rustc via
# rust-toolchain.toml / a flake devShell.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  sccache = lib.getExe pkgs.sccache;
in
{
  home.packages = [ pkgs.sccache ];

  home.sessionVariables = {
    RUSTC_WRAPPER = sccache;

    # sccache cannot cache rustc invocations that use incremental compilation
    # (`-C incremental=...`), and cargo turns that on for dev profiles by
    # default. Reports them as "incremental" under Non-cacheable reasons and
    # compiles them normally, so the cache would never hit. Per-invocation
    # override (`CARGO_INCREMENTAL=1 cargo build`) wins if you would rather have
    # incremental rebuilds while iterating on a single crate.
    CARGO_INCREMENTAL = "0";
  };

  # Read by both the client and the server. 50 GiB of content-addressed objects;
  # sccache evicts least-recently-used entries past that.
  xdg.configFile."sccache/config".text = ''
    [cache.disk]
    dir = "${config.xdg.cacheHome}/sccache"
    size = ${toString (50 * 1024 * 1024 * 1024)}
  '';

  # sccache starts a server on demand, but a user unit means its log goes to the
  # journal instead of a temp file and the server is not reaped mid-session
  # (SCCACHE_IDLE_TIMEOUT=0 disables the 10 minute idle shutdown).
  systemd.user.services.sccache = {
    Unit = {
      Description = "sccache compiler cache server";
      documentation = [ "https://github.com/mozilla/sccache" ];
    };
    Service = {
      ExecStart = "${sccache} --start-server";
      ExecStop = "${sccache} --stop-server";
      Environment = [ "SCCACHE_IDLE_TIMEOUT=0" ];
      Type = "oneshot";
      RemainAfterExit = true;
    };
    Install.WantedBy = [ "default.target" ];
  };
}
