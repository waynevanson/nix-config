{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  runCommand,
}:

let
  version = "unstable-2026-08-25";
  src = fetchFromGitHub {
    owner = "amosblomqvist";
    repo = "pi-config";
    rev = "f82da563ab05d66729492d64c7ed4e96db3663f3";
    hash = "sha256-G3q+6YO3CvwkpUwx+qYitrWJB8HSUF6WJ66LRjujmVY=";
  };

  # Directory extensions need their node_modules next to index.ts so pi's
  # loader resolves runtime deps. Copy the extension files + node_modules
  # into a flat output (bypasses npmInstallHook's `npm pack`, which fails on
  # extension package.json files that lack a version field).
  browser = buildNpmPackage {
    pname = "pi-extension-browser";
    inherit version src;
    sourceRoot = "source/extensions/browser";
    npmDepsHash = "sha256-dh+GrLV8hftXbtmY+HjlsQNwK59KWCmxsL7AerYSKOs=";
    dontNpmBuild = true;
    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp package.json index.ts $out/
      cp -r node_modules $out/node_modules
      runHook postInstall
    '';
    meta = {
      description = "Playwright-driven headless browser tools for pi";
      homepage = "https://github.com/amosblomqvist/pi-config";
      license = lib.licenses.mit;
    };
  };

  web-fetch = buildNpmPackage {
    pname = "pi-web-fetch";
    inherit version src;
    sourceRoot = "source/extensions/web-fetch";
    npmDepsHash = "sha256-Rbdj6jd25Urxr1wJj1Vl7mefv1IKu5zQhHgt6dOEqaU=";
    dontNpmBuild = true;
    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp package.json index.ts $out/
      cp -r node_modules $out/node_modules
      runHook postInstall
    '';
    meta = {
      description = "Web fetch extension for pi";
      homepage = "https://github.com/amosblomqvist/pi-config";
      license = lib.licenses.mit;
    };
  };
in
runCommand "pi-amosblomqvist-extensions"
  {
    meta = {
      description = "Browser, web-fetch, web-search, and ask-user-question extensions for pi";
      homepage = "https://github.com/amosblomqvist/pi-config";
      license = lib.licenses.mit;
    };
  }
  ''
    mkdir -p $out
    cp -r ${browser} $out/browser
    cp -r ${web-fetch} $out/web-fetch
    cp -r ${src}/extensions/web-search $out/web-search
    cp -r ${src}/extensions/prompt-snippets $out/prompt-snippets
    cp ${src}/extensions/ask-user-question.ts $out/ask-user-question.ts
  ''
