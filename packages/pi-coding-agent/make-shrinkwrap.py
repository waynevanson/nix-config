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
    "@earendil-works/chord": "sha512-gsHzKfyQ3t0ZIQ3cLBjJ5Vqy1TYnFyruHIV3g3BwmulCDYe5BW4yT9vaJk9QzN6YANILIO75uzuq+Gdxtzz1og==",
    "@earendil-works/pi-agent-core": "sha512-aX1KZomNCPmwYnXa3OivF3VYLJ+WPUkIJlEIZTgwdOZdY/+oToWTQ334WYpQeOz9POpiYFNMJLPwIhXQ4e48kg==",
    "@earendil-works/pi-ai": "sha512-1T7LAkc/5Bvc0v6w4vAGVdCrli0o/E0pEmYKTnixu95vSFArBjvbhS/G4ZwI0RUePgf0Imcu0VyqlM4EcXxqfw==",
    "@earendil-works/pi-codemode": "sha512-8Asc2AzhoNaXS1snmRFa96OhcWIlFM5k1Kuiz6p2DvIYgi5QHQccRAmDVY9oO92TzWrizpvQpconZGQ7JhlI7Q==",
    "@earendil-works/pi-mcp": "sha512-xGKwvu3SvVTeoIx8Z7UGoJprB4VK20wKORMhufcWGx61fIauhu3J+UqfB5eeoF1oE/geYBA598K6nh1SdABQkg==",
    "@earendil-works/pi-telemetry": "sha512-8gAK05/2pPozZZz6hCLOi8x2vsqzvsmO9gG92kbvuvTPm0qMHaFlaXX98ndXsrOi5pmzha7vNLguuG4+0Rgxjw==",
    "@earendil-works/pi-tui": "sha512-v7wkS0y2ErZvZkSfemqd9RrBZJ5x6p8Ujsv7NdJj01IXJyFM0kNL6rMdcKcvTe7EVTd6ugvDB9VPZSoaBF9QxQ==",
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
