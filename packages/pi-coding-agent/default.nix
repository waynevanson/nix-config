{
  lib,
  buildNpmPackage,
  fetchurl,
  python3,
  runCommand,
}:

let
  version = "0.79.9";

  upstream = fetchurl {
    url = "https://registry.npmjs.org/@earendil-works/pi-coding-agent/-/pi-coding-agent-${version}.tgz";
    hash = "sha512-8TZ796Zn0NE4vmhxG9hv4ZtJDGJzhqMjlmFg8ZkUKxfqB7LJa4ums2jSJKtnyAZfAamN6VzqzN0A82RNDqv8Ag==";
  };

  src = runCommand "pi-coding-agent-${version}-patched.tar.gz"
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
  npmDepsHash = "sha256-d8EGQ4F6ZYGpVSNlPgsGR/XuddbnVQSEpiH5MM4TT3Y=";

  dontNpmBuild = true;

  meta = {
    description = "Coding agent CLI with read, bash, edit, write tools and session management";
    homepage = "https://pi.dev";
    license = lib.licenses.mit;
    mainProgram = "pi";
  };
}
