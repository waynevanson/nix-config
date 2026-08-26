{
  lib,
  buildNpmPackage,
  fetchurl,
  python3,
  runCommand,
}:

let
  version = "0.84.3";
  upstream = fetchurl {
    url = "https://registry.npmjs.org/@earendil-works/pi-coding-agent/-/pi-coding-agent-${version}.tgz";
    hash = "sha256-0H3EF/eKFNrDdqh4tlVrUZYfEY95dx7jdTM9xRNWvHU=";
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
  npmDepsHash = "sha256-MrJ1+yclWHt2UUSdqHdB5x7riJDGrNySlNDn5dcPwDo=";
  dontNpmBuild = true;
  meta = {
    description = "Coding agent CLI with read, bash, edit, write tools and session management";
    homepage = "https://pi.dev";
    license = lib.licenses.mit;
    mainProgram = "pi";
  };
}
