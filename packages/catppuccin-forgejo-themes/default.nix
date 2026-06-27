{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  fetchurl,
  dart-sass,
}:

stdenvNoCC.mkDerivation rec {
  pname = "catppuccin-forgejo-themes";
  version = "unstable-2026-06-27";

  src = fetchFromGitHub {
    owner = "rdcsq";
    repo = "catppuccin-forgejo";
    rev = "d09f5b96590e36906ab26eddcbbc4c3bf92f4af9";
    hash = "sha256-EPcU9G36WjWgrW7DtPQGDZtIbYI3+1eTGG2CPIratcY=";
  };

  palette = fetchurl {
    url = "https://registry.npmjs.org/@catppuccin/palette/-/palette-1.8.0.tgz";
    hash = "sha512-qXhwKiLzQomUygUJYB36YAFgs+dET5bIocfkiaFIatQF5Pwc7L112TlF9P8J5Oqs3x3XTjYSucG0ncHXSCuk7Q==";
  };

  nativeBuildInputs = [ dart-sass ];

  buildPhase = ''
    runHook preBuild

    mkdir -p node_modules/@catppuccin
    tar -xzf ${palette} -C node_modules/@catppuccin
    mv node_modules/@catppuccin/package node_modules/@catppuccin/palette

    mkdir -p dist

    for flavor in latte frappe macchiato mocha; do
      isDark=true
      [ "$flavor" = "latte" ] && isDark=false
      for accent in rosewater flamingo pink mauve red maroon peach yellow green teal sky sapphire blue lavender; do
        scss="dist/build-$flavor-$accent.scss"
        cat > "$scss" <<EOF
@import "@catppuccin/palette/scss/$flavor";
\$accent: \$$accent;
\$isDark: $isDark;
@import "theme";
EOF
        sass --load-path=src --load-path=node_modules --no-source-map "$scss" "dist/theme-catppuccin-$flavor-$accent.css"
      done
    done

    for accent in rosewater flamingo pink mauve red maroon peach yellow green teal sky sapphire blue lavender; do
      cat > "dist/theme-catppuccin-$accent-auto.css" <<EOF
@import "./theme-catppuccin-latte-$accent.css" (prefers-color-scheme: light);
@import "./theme-catppuccin-mocha-$accent.css" (prefers-color-scheme: dark);
EOF
    done

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
