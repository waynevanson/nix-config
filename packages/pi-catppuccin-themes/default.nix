{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:

stdenvNoCC.mkDerivation {
  pname = "pi-catppuccin-themes";
  version = "unstable-2026-03-15";
  src = fetchFromGitHub {
    owner = "nairvarun";
    repo = "catppuccin-pi";
    rev = "766c73902c8ac2c32288e5abf72cfc6c461c1158";
    hash = "sha256-mtv7cukzKzmiRftJJyA3bZ1/ye9xWGWLz8H1Kt2aETo=";
  };
  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/pi/themes
    install -m 444 themes/catppuccin-mocha.json themes/catppuccin-latte.json $out/share/pi/themes/

    runHook postInstall
  '';
  meta = {
    description = "Catppuccin Mocha and Latte themes for the Pi coding agent";
    homepage = "https://github.com/nairvarun/catppuccin-pi";
    license = lib.licenses.mit;
  };
}
