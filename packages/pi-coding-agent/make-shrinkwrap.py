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
    "@earendil-works/chord": "sha512-zSmZ4FINxIBsy0iq5TPJXSVBtxHenKthU+svqxH1RbPGIDID/yjCg+wKk6IzsAsJAPmUGoP5yxD0Ap11ZGkefA==",
    "@earendil-works/pi-agent-core": "sha512-jD4qinlcwO3AoN/97v0AG3b0Umz/7hIBlEStmz6M3AQNicWOU+UK851fdDvzvCCukpQBSyOraEGRFMTgj+xGpA==",
    "@earendil-works/pi-ai": "sha512-ukMQ78DE1ypirehoWOrg32dZNEQsY/VXRETPJf5qgdpaw8abq/jlALpQpiEpRDyCkCyX/9FPiQRIazw7FA1FCw==",
    "@earendil-works/pi-codemode": "sha512-xVuCpni7AuLPhvrN+oCP9Kcq0I2kY8SdtJRNMevQMmC2DcuQcgSWgOH2KOtuG0/Ihe1BZgPCahY4q5oiFMHw4g==",
    "@earendil-works/pi-mcp": "sha512-cUFhLnanLjBf8+NpHU+shJTzvcfLBjjDI02tI7hSmYnYqNfhqXhFPEkqT8G+/e+PX6r46DX1ZU54BTC5+p+MRA==",
    "@earendil-works/pi-schema": "sha512-QmvyJYVTva2ZT6/R2rFL64nmaiRmc6hCHv9ZoVNeyDhvLbRHIQLU8mI140vuX6JOnT7tCEd74GOyui/MIRF7ww==",
    "@earendil-works/pi-telemetry": "sha512-uFi8XzG10gMgz9LggOlQW4CvEe/t1wZ6bwLChx36rmyZE7ogg/jHKTGekG73o6Rkwxi0bqE2AnTk+RZ4GmYQ2w==",
    "@earendil-works/pi-tui": "sha512-UZkaMYLuJrk2anJhZf06dNYdLWL8toqWNL807fhAorc8Lzy5vkxWNq/pC1f0CIM2EVdlctuRibWuIQGKYOgx+A==",
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
