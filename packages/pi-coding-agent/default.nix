{
  lib,
  buildNpmPackage,
  fetchurl,
  python3,
  runCommand,
}:

let
  version = "0.80.2";
  upstream = fetchurl {
    url = "https://registry.npmjs.org/@earendil-works/pi-coding-agent/-/pi-coding-agent-${version}.tgz";
    hash = "sha256-nKsYZhU0XzzCqx0199bxOTBqMSKgMKRffCRUifc0kIU=";
  };
  src =
    runCommand "pi-coding-agent-${version}-patched.tar.gz"
      {
        nativeBuildInputs = [ python3 ];
      }
      ''
        mkdir -p work
        tar xzf ${upstream} -C work
        cd work/package

        python3 ${./prune-dev-deps.py} npm-shrinkwrap.json

        cd ..
        tar czf $out package
      '';
in
buildNpmPackage {
  pname = "pi-coding-agent";
  inherit version src;
  sourceRoot = "package";
  npmDepsFetcherVersion = 2;
  npmDepsHash = "sha256-LmnQRKb6HTYPnnS30x9vrqwTWtXw+kNpuX4oZkaxWHk=";
  dontNpmBuild = true;
  meta = {
    description = "Coding agent CLI with read, bash, edit, write tools and session management";
    homepage = "https://pi.dev";
    license = lib.licenses.mit;
    mainProgram = "pi";
  };
}
