#!/usr/bin/env python3
import json
import sys
from pathlib import Path
from collections import deque

workspace_integrity = {
    "@earendil-works/chord": "sha512-BIfWfrByM0pKq6tfKYXuwx0ed2CvaqIM3EDA7Dps+fP+d3CiPWdlHi1cDsJC05llqKJoRz5//G0hz0yQwwjISQ==",
    "@earendil-works/pi-agent-core": "sha512-bHFONjtEBDqiV+g1DmmtkSlfAaqHELr+XO+6I5Nah4gswwZrLJO4yZB/JjsnlI4AKWTayBLfgS6DCbeBBz9e2Q==",
    "@earendil-works/pi-ai": "sha512-3/W1vdDaVtpeMd23ElvJC12HLA5yS/BGqqcXF+0SK082dN7cbgNcCwguTBRBC258Ke8SzSvUW1B75iAf8w8IxA==",
    "@earendil-works/pi-codemode": "sha512-LPpFI4+T9NzDnhBDs15izWAolaoM8xnwqdziRd6Zx8BQeoEPvzefD2vMMzSyF0rOtq34TfQqkZ0ki16f6cGdMg==",
    "@earendil-works/pi-mcp": "sha512-rYra0aF5iPmJd+fsB+VBuqxWNABGJ3Iiyhg0CqIc/91ta2n7IvQmCp0Cac/YkUTNnvRsVZnjgAiBkRi6+ouWuw==",
    "@earendil-works/pi-telemetry": "sha512-WjNBj5TYIiPZFQEz2WlULcDwPLaKwIlmsKjVeYM+LJSbnSp38kWsHUJysIDGnu23IcLbKoPtywsvYfUJCeZePA==",
    "@earendil-works/pi-tui": "sha512-JsT7kXnpZA2YOtQu6RyriyxEO0eJIzPyfiH09bH+OLN5+s18HYkwaUD/tBkjhnSfMu6/50CQPRYJagzSP6HdPw==",
}


def resolve_dep(parent_path: str, dep_name: str, packages: dict) -> str | None:
    """Find the installed path for dep_name required by parent_path."""
    parts = Path(parent_path).parts
    # Walk up from parent_path towards the root, preferring nested locations.
    for i in range(len(parts), -1, -1):
        candidate = str(Path(*parts[:i]) / "node_modules" / dep_name)
        if candidate == "/node_modules/" + dep_name:
            candidate = "node_modules/" + dep_name
        if candidate in packages:
            return candidate
    return None


def prune(path: Path) -> None:
    with open(path) as f:
        data = json.load(f)

    packages = data.get("packages", {})
    root = packages.get("", {})

    # Remove devDependencies from the root package so npm does not try to
    # install them.
    root.pop("devDependencies", None)

    # Also drop devDependencies from package.json so npm does not attempt to
    # reconcile them against the lockfile.
    package_json = Path("package.json")
    if package_json.exists():
        with open(package_json) as f:
            pkg = json.load(f)
        pkg.pop("devDependencies", None)
        with open(package_json, "w") as f:
            json.dump(pkg, f, indent="\t", separators=(",", ": "))
            f.write("\n")

    # Add missing integrity hashes for workspace packages.
    for pkg_name, integrity in workspace_integrity.items():
        key = f"node_modules/{pkg_name}"
        if key in packages and "integrity" not in packages[key]:
            packages[key]["integrity"] = integrity

    # BFS over runtime dependency graph to keep only reachable packages.
    reachable = set()
    queue = deque([""])

    while queue:
        current = queue.popleft()
        if current in reachable:
            continue
        reachable.add(current)

        pkg = packages.get(current, {})
        deps = {}
        deps.update(pkg.get("dependencies", {}))
        deps.update(pkg.get("optionalDependencies", {}))

        for dep_name in deps:
            target = resolve_dep(current, dep_name, packages)
            if target is not None:
                queue.append(target)

    # Keep only reachable packages.
    data["packages"] = {k: v for k, v in packages.items() if k in reachable}

    with open(path, "w") as f:
        json.dump(data, f, indent="\t", separators=(",", ": "))
        f.write("\n")


if __name__ == "__main__":
    prune(Path(sys.argv[1]))
