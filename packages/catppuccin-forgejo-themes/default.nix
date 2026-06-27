{
  lib,
  stdenvNoCC,
  fetchurl,
}:

stdenvNoCC.mkDerivation rec {
  pname = "catppuccin-forgejo-themes";
  version = "1.0.2";

  src = fetchurl {
    url = "https://github.com/catppuccin/gitea/releases/download/v${version}/catppuccin-gitea.tar.gz";
    hash = "sha256-HP4Ap4l2K1BWP1zWdCKYS5Y5N+JcKAcXi+Hx1g6MVwc=";
  };

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/forgejo/public/assets/css
    cp ./*.css $out/share/forgejo/public/assets/css/

    runHook postInstall
  '';

  meta = {
    description = "Catppuccin themes for Forgejo (from the Gitea port)";
    homepage = "https://github.com/catppuccin/gitea";
    license = lib.licenses.mit;
  };
}
