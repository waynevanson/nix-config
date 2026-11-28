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
    "@earendil-works/pi-agent-core": "sha512-pLs/wTAcrUnKDILPHjnd7RiDZSotAhJ965LwVc8x37TeWF+k+vKPMmAW6Z1T8XMQuICbIYusjkT7K0lmjgQwrg==",
    "@earendil-works/pi-ai": "sha512-iKryMlUYniwWbU7YU0uS7W0+cGd9c6oJ6PzRLOn8j4+1njG4c+BQq1cNawctx/npDqGeOx8ME7Gkgl6K6arPuw==",
    "@earendil-works/pi-codemode": "sha512-fhCoh8TLxhdRTOWSEplwp39Uv+JTsu9pCqtgu9gorO8zcaw92vsbVI/G89yFs92csTo2+yB7EsJq/+725Vj+eA==",
    "@earendil-works/pi-mcp": "sha512-ScsDjuFXjT9eKioD5oyZqofDXtaWCMhCBa+1aDSh7WmRACLsohfGQJtAX1rv5OmEbaerrRPgyD5jgwJFBjTFNw==",
    "@earendil-works/pi-schema": "sha512-skji4McLg9jum3NFWzFa/4QRGEZhMGnSi3QL8b9VljJkc/QopH2/BFuGKI+VcEwYzKGwsd0I8RzvXGnZGfGltQ==",
    "@earendil-works/pi-telemetry": "sha512-QZkngqktohuFZ2TZuJSXDuUntld4sCMW1tkUPaD4moMEX/z1lwcjycXnd9ChO9HNxm/Jfo+UTiC+N2hkAF9b0w==",
    "@earendil-works/pi-tui": "sha512-C6vkUYGTeDdl/cMIbFOabSEPMRy9HuaUV76PS2BhvSmWifO5y8Rz8/LgFWqGIIFS7RMqu0gdeEpdXfH8jIp05g==",
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
