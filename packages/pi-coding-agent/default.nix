{
  lib,
  buildNpmPackage,
  fetchurl,
  python3,
  runCommand,
}:

let
  version = "1.1.0";
  upstream = fetchurl {
    url = "https://registry.npmjs.org/@earendil-works/pi-coding-agent/-/pi-coding-agent-${version}.tgz";
    hash = "sha512-SeEi/4hdcHNgA9UWlefZl7ZZpm3dzi2OoxNjDHsBJ9o298LNOtbL4DGKgitlEj6uCTccvtw6f2hlCkTPVJ2RXg==";
  };
  # Published tarballs no longer ship a lockfile; upstream publishes this
  # install lock instead. See make-shrinkwrap.py.
  installLock = fetchurl {
    url = "https://raw.githubusercontent.com/earendil-works/pi/v${version}/packages/coding-agent/install-lock/package-lock.json";
    hash = "sha256-iaU/pnKXF3utQtcenrnH6uucf8NNPPtoAMGzj7wpPrs=";
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
  npmDepsHash = "sha256-JxaNA4+q+kav9iss3KxPzSprChj6MmL2ITcHk3INpQQ=";
  dontNpmBuild = true;
  meta = {
    description = "Coding agent CLI with read, bash, edit, write tools and session management";
    homepage = "https://pi.dev";
    license = lib.licenses.mit;
    mainProgram = "pi";
  };
}
