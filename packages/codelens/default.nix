{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  python3,
  gnumake,
  gcc,
}:

buildNpmPackage {
  pname = "codelens";
  version = "2.2.2";
  src = fetchFromGitHub {
    owner = "ex-git";
    repo = "codeLens";
    rev = "v2.2.2";
    hash = "sha256-M9+7utcpboGzvy01iXK80Ft0Q4ZzSzcVga/EuDrd0LY=";
  };
  npmDepsHash = "sha256-3M8Z1znoKbgla6UEyw8m5DUoskVVhtgrHEYNIEv+ePQ=";
  nativeBuildInputs = [
    python3
    gnumake
    gcc
  ];
  env.CXXFLAGS = "-std=c++20";
  meta = {
    description = "CodeLens code context index server";
    homepage = "https://github.com/ex-git/codeLens";
    license = lib.licenses.mit;
  };
}
