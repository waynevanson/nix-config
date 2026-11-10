{
  lib,
  buildNpmPackage,
  fetchurl,
  python3,
  runCommand,
}:

let
  version = "1.5.1";
  upstream = fetchurl {
    url = "https://registry.npmjs.org/@earendil-works/pi-coding-agent/-/pi-coding-agent-${version}.tgz";
    hash = "sha512-rdu4pRvpQba2ep83nqHaN8L1pvY1OQ3i/2FucogA/eyRxwoUXMUXdk1Z9JnZFJR+9ck9Gs1ajuSb9m7Hz7ejYw==";
  };
  # Published tarballs no longer ship a lockfile; upstream publishes this
  # install lock instead. See make-shrinkwrap.py.
  installLock = fetchurl {
    url = "https://raw.githubusercontent.com/earendil-works/pi/v${version}/packages/coding-agent/install-lock/package-lock.json";
    hash = "sha256-Y/PYDDcswTmx8jlw1Qz2E6El9gcQQc93j57IjVEHbig=";
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
  npmDepsHash = "sha256-qRvjhByvKoYsi70YtGHYA+r+eKvU+bZBQ7RRSB9xjFA=";
  dontNpmBuild = true;
  meta = {
    description = "Coding agent CLI with read, bash, edit, write tools and session management";
    homepage = "https://pi.dev";
    license = lib.licenses.mit;
    mainProgram = "pi";
  };
}
