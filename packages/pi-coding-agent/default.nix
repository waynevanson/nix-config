{
  lib,
  buildNpmPackage,
  fetchurl,
  python3,
  runCommand,
}:

let
  version = "1.7.0";
  upstream = fetchurl {
    url = "https://registry.npmjs.org/@earendil-works/pi-coding-agent/-/pi-coding-agent-${version}.tgz";
    hash = "sha256-ywMf85t10EJ5fXSAM5h92cDlZzczlxcsC07WYdC/SCQ=";
  };
  # Published tarballs no longer ship a lockfile; upstream publishes this
  # install lock instead. See make-shrinkwrap.py.
  installLock = fetchurl {
    url = "https://raw.githubusercontent.com/earendil-works/pi/v${version}/packages/coding-agent/install-lock/package-lock.json";
    hash = "sha256-taFdIfeAXLuzUWUgKhF3Z1tnWq33/Kc6S68k+BUn3II=";
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

        python3 ${./make-shrinkwrap.py} ${installLock} package.json npm-shrinkwrap.json

        cd ..
        tar czf $out package
      '';
in
buildNpmPackage {
  pname = "pi-coding-agent";
  inherit version src;
  sourceRoot = "package";
  npmDepsFetcherVersion = 2;
  npmDepsHash = "sha256-Q5Bhjca5dK8YKhLFQzG9RkvILQlBcLwhnNKY7FW2BTo=";
  dontNpmBuild = true;
  meta = {
    description = "Coding agent CLI with read, bash, edit, write tools and session management";
    homepage = "https://pi.dev";
    license = lib.licenses.mit;
    mainProgram = "pi";
  };
}
