{ pkgs, ... }:
(pkgs.pi-coding-agent.overrideAttrs rec {
  version = "0.67.3";
  src = pkgs.fetchFromGitHub {
    owner = "badlogic";
    repo = "pi-mono";
    tag = "v${version}";
    hash = "sha256-2hSf1X42sH5jhVKCiZM/EIEfQae2mFUX6FGVM/vgtPc=";
  };
  npmDepsHash = "sha256-3xFxY0iKiwjM0psijzdSqed5UOjIAOyWPwQ15fqfc4I=";
  npmDeps = pkgs.fetchNpmDeps {
    inherit src;
    name = "pi-coding-agent-${version}-npm-deps";
    hash = npmDepsHash;
  };
})
