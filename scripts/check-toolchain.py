"""Enforce the acceptance compiler floor, optionally the reproducible SDK/core pin."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--pinned", action="store_true")
    args = parser.parse_args()
    config = json.loads((ROOT / "toolchain.json").read_text(encoding="utf-8"))
    result = subprocess.run(["moon", "version", "--all"], capture_output=True, text=True, check=True)
    match = re.search(r"moonc v?(\d+\.\d+\.\d+(?:\+[\w.]+)?)", result.stdout)
    if match is None:
        raise SystemExit("Cannot identify moonc in moon version --all")
    version = match[1]
    numeric = tuple(map(int, version.split("+")[0].split(".")))
    minimum = tuple(map(int, config["minimum_compiler"].split(".")))
    if numeric < minimum:
        raise SystemExit(f"moonc {version} is below required {config['minimum_compiler']}; select the project toolchain")
    core_version = None
    if args.pinned:
        sdk_home = os.environ.get("MOON_HOME")
        if not sdk_home:
            raise SystemExit("Pinned checks require MOON_HOME to select the SDK and core together")
        manifest = Path(sdk_home) / "lib/core/moon.mod"
        core = re.search(r'^version\s*=\s*"([^"]+)"', manifest.read_text(encoding="utf-8"), re.M)
        core_version = core[1] if core else None
        if version != config["sdk_version"] or core_version != config["core_version"]:
            raise SystemExit(f"SDK/core mismatch: compiler={version}, core={core_version}")
    print(json.dumps(dict(compiler=version, minimum=config["minimum_compiler"], core=core_version, pinned=args.pinned)))


if __name__ == "__main__":
    main()
