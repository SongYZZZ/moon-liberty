"""Fetch immutable interoperability inputs; no runtime dependency or data vendoring."""
import gzip
import hashlib
import json
from pathlib import Path
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "docs/standards/corpus.json"


def main():
    destination = ROOT / ".tools/corpus"
    destination.mkdir(parents=True, exist_ok=True)
    for item in json.loads(MANIFEST.read_text(encoding="utf-8"))["downloads"]:
        target = destination / item["file"]
        if target.exists() and hashlib.sha256(target.read_bytes()).hexdigest() == item["sha256"]:
            continue
        with urllib.request.urlopen(item["url"], timeout=60) as response:
            data = response.read(20_000_001)
        assert len(data) <= 20_000_000, "download budget exceeded"
        if item.get("gzip"):
            assert hashlib.sha256(data).hexdigest() == item["download_sha256"]
            data = gzip.decompress(data)
        assert hashlib.sha256(data).hexdigest() == item["sha256"], item["file"]
        target.write_bytes(data)
    print("Verified immutable corpus files and license texts in .tools/corpus")


if __name__ == "__main__":
    main()
