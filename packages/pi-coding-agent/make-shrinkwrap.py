#!/usr/bin/env python3
"""Generate an npm-shrinkwrap.json for the published pi-coding-agent package.

The published tarball no longer ships a lockfile. Instead upstream generates a
dedicated install lock (``packages/coding-agent/install-lock/package-lock.json``)
that pins the exact runtime dependency tree for a given release. That lock is
rooted at an installer package that depends on ``@earendil-works/pi-coding-agent``
itself, so we rewrite its root entry to be the coding-agent package and drop the
self-referential node_modules entry.

Usage: make-shrinkwrap.py <install-lock.json> <package.json> <output.json>
"""

import json
import sys
from pathlib import Path

SELF = "@earendil-works/pi-coding-agent"

# The install lock omits integrity for the internal workspace packages (they are
# generated from the monorepo rather than downloaded). Supply the registry
# hashes so `npm ci` can fetch them reproducibly.
WORKSPACE_INTEGRITY = {
    "@earendil-works/pi-agent-core": "sha512-IU/x+2XtE4KIdIkEndZssdLPbIUR38Btj+Q7vjIIXIK7GSamLtDH5jOw/dzBWAvWFAgZ2dslF5sPc6GcGOnS+w==",
    "@earendil-works/pi-ai": "sha512-9hL+eygFDEiFp//cydeUfmFsKmEqpmvsNPb10Y1W8+m5K9O+sx1hMStfu6nukrBD5sl6mP4RykCYBBNEgsVLfw==",
    "@earendil-works/pi-codemode": "sha512-GAgAy7iJCVbeiuqq2dTIuNj3aXTMUeTF8Nu8LZs72e8ueGGDU5L3/D8VxzTHALIpQ1/q8u1tfmB3iYS2Nopchw==",
    "@earendil-works/pi-mcp": "sha512-dhqAR6MP8Fp3b8LEcBFOyxMZpGSozUAdzF0Dbl7OvojsjZrQsDV3ZKn85WRbwjHb4WjQUCVBsIZXwoyQxXeunw==",
    "@earendil-works/pi-schema": "sha512-jD0VRCUcFzWQ5zN82pOuoHNN42/3pu4E5krtpiKknvPq4g2m+fuO38lj+xnZhuVpYcd2G0qlmr8lE6ZMzkad7Q==",
    "@earendil-works/pi-telemetry": "sha512-MNL0TvtpgoSfX7mBLSVgzxTW6yvT8VLEpHvbWnZsIp92FtqVvx+4q9DxWZdX8KvcQqBs0GseAgVnLdVFinjN9Q==",
    "@earendil-works/pi-tui": "sha512-nVtWZ4rYr3KHDla3skGAWG5XoITEUJCoEx1AsWv1yKxV7+v86ulD2hxVn/P+COI6jsoeQmj3orqHbCHZwAUsUg==",
}

ROOT_FIELDS = (
    "license",
    "dependencies",
    "optionalDependencies",
    "peerDependencies",
    "peerDependenciesMeta",
    "bin",
    "engines",
    "os",
    "cpu",
    "libc",
    "overrides",
)


def sorted_object(obj: dict) -> dict:
    return {k: obj[k] for k in sorted(obj)}


def main() -> None:
    install_lock_path, package_json_path, output_path = map(Path, sys.argv[1:4])

    lock = json.loads(install_lock_path.read_text())
    package = json.loads(package_json_path.read_text())
    packages = lock["packages"]

    # Dev dependencies are not part of the install lock, so drop them from the
    # manifest as well; otherwise `npm ci` tries to reconcile them.
    package.pop("devDependencies", None)
    package_json_path.write_text(json.dumps(package, indent="\t") + "\n")

    root = {"name": package["name"], "version": package["version"]}
    for field in ROOT_FIELDS:
        if field in package:
            root[field] = package[field]

    internal = {f"node_modules/{name}": integrity for name, integrity in WORKSPACE_INTEGRITY.items()}

    rewritten = {"": root}
    for path, entry in packages.items():
        if path == "":
            continue
        # The coding-agent itself is the source package, not a dependency.
        if path == f"node_modules/{SELF}":
            continue
        entry.pop("dev", None)
        entry.pop("devOptional", None)
        entry.pop("extraneous", None)
        entry.pop("link", None)
        if path in internal:
            entry.setdefault("integrity", internal[path])
        rewritten[path] = entry

    shrinkwrap = {
        "name": package["name"],
        "version": package["version"],
        "lockfileVersion": 3,
        "requires": True,
        "packages": sorted_object(rewritten),
    }
    output_path.write_text(json.dumps(shrinkwrap, indent="\t") + "\n")


if __name__ == "__main__":
    main()
