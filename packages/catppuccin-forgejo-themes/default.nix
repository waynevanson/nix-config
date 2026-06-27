{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  deno,
  jq,
}:

let
  src = fetchFromGitHub {
    owner = "rdcsq";
    repo = "catppuccin-forgejo";
    rev = "d09f5b96590e36906ab26eddcbbc4c3bf92f4af9";
    hash = "sha256-EPcU9G36WjWgrW7DtPQGDZtIbYI3+1eTGG2CPIratcY=";
  };

  denoDeps = stdenvNoCC.mkDerivation {
    name = "catppuccin-forgejo-deno-deps";
    inherit src;

    nativeBuildInputs = [
      deno
      jq
    ];

    dontFixup = true;

    buildPhase = ''
      runHook preBuild

      cat deno.json | jq '.vendor = true' > deno.json.new
      mv deno.json.new deno.json

      export DENO_DIR=$TMPDIR/deno_dir
      deno cache build.ts

      mkdir -p $out/deno_dir
      cp -r $DENO_DIR/npm $out/deno_dir/npm
      cp -r vendor $out/vendor

      runHook postBuild
    '';

    outputHashMode = "recursive";
    outputHashAlgo = "sha256";
    outputHash = "sha256-2d2gjG1KOxsh/q20RB9OIlsA0mAXzlkBohHnE8tTeZc=";
  };
in

stdenvNoCC.mkDerivation rec {
  pname = "catppuccin-forgejo-themes";
  version = "unstable-2026-06-27";

  inherit src;

  nativeBuildInputs = [
    deno
    jq
  ];

  buildPhase = ''
    runHook preBuild

    cat deno.json | jq '.vendor = true' > deno.json.new
    mv deno.json.new deno.json

    mkdir -p $TMPDIR/deno_dir
    cp -r ${denoDeps}/deno_dir/npm $TMPDIR/deno_dir/npm
    chmod -R +w $TMPDIR/deno_dir
    export DENO_DIR=$TMPDIR/deno_dir

    ln -s ${denoDeps}/vendor vendor

    deno run -A --cached-only build.ts

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/forgejo/public/assets/css
    cp dist/theme-*.css $out/share/forgejo/public/assets/css/

    runHook postInstall
  '';

  meta = {
    description = "Catppuccin themes for Forgejo";
    homepage = "https://github.com/rdcsq/catppuccin-forgejo";
    license = lib.licenses.mit;
  };
}
