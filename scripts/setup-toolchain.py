"""Install the pinned Windows x64 SDK in .tools without altering system settings."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import subprocess
import tempfile
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--downloads", type=Path)
    args = parser.parse_args()
    if os.name != "nt" or platform.machine().lower() not in {"amd64", "x86_64"}:
        raise SystemExit("This helper is for Windows x64; other platforms use the pinned SDK in toolchain.json")
    config = json.loads((ROOT / "toolchain.json").read_text(encoding="utf-8"))
    destination = ROOT / ".tools/moon016"
    marker = destination / "moonliberty-install.json"
    if destination.exists():
        if marker.is_file() and json.loads(marker.read_text(encoding="utf-8")) == config:
            print(f"Pinned SDK already installed: {destination}")
            return
        raise SystemExit(f"Existing directory left untouched: {destination}; inspect it before installing")
    default_temp = Path("D:/Dev/Temp") if Path("D:/Dev/Temp").is_dir() else Path(tempfile.gettempdir())
    downloads = (args.downloads or default_temp / "moon-liberty-sdk016").resolve()
    downloads.mkdir(parents=True, exist_ok=True)
    archives = []
    for name, url, digest in (("sdk.zip", config["windows_sdk_url"], config["windows_sdk_sha256"]),
                              ("core.zip", config["core_url"], config["core_sha256"])):
        path = downloads / name
        if not path.exists():
            request = urllib.request.Request(url, headers={"User-Agent": "curl/8.9"})
            with urllib.request.urlopen(request, timeout=60) as response, path.open("xb") as output:
                while chunk := response.read(1024 * 1024):
                    output.write(chunk)
        if hashlib.sha256(path.read_bytes()).hexdigest() != digest:
            raise SystemExit(f"Checksum mismatch; file preserved for inspection: {path}")
        archives.append(path)
    destination.mkdir(parents=True)
    for archive, target in zip(archives, (destination, destination / "lib")):
        with zipfile.ZipFile(archive) as package:
            for entry in package.infolist():
                if not (target / entry.filename).resolve().is_relative_to(target.resolve()):
                    raise SystemExit("Archive entry escapes the new SDK directory")
            package.extractall(target)
    environment = os.environ.copy()
    environment["MOON_HOME"] = str(destination)
    environment["PATH"] = str(destination / "bin") + os.pathsep + environment.get("PATH", "")
    subprocess.run([str(destination / "bin/moon.exe"), "-C", str(destination / "lib/core"), "bundle", "--all"], env=environment, check=True)
    subprocess.run([os.sys.executable, str(ROOT / "scripts/check-toolchain.py"), "--pinned"], env=environment, check=True)
    marker.write_text(json.dumps(config, indent=2) + "\n", encoding="utf-8")
    print(f"Installed {config['sdk_version']} in {destination}. Run: . ./scripts/use-toolchain.ps1")


if __name__ == "__main__":
    main()
