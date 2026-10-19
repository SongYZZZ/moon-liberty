"""Portable CLI, packaging and submission-identity checks. Python stdlib only."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import re
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
REPOSITORY = "https://github.com/SongYZZZ/moon-liberty"
NAME = "MoonLiberty"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--executable", required=True, type=Path)
    ap.add_argument("--identity", action="store_true")
    ap.add_argument("--benchmark", action="store_true")
    args = ap.parse_args()
    exe = args.executable.resolve()
    count = 0

    def run(*argv, code=0, parse=True):
        nonlocal count
        p = subprocess.run([str(exe), *map(str, argv)], cwd=ROOT, text=True,
                           encoding="utf-8", capture_output=True, timeout=30, check=False)
        assert p.returncode == code, (argv, code, p.returncode, p.stdout, p.stderr)
        count += 1
        return json.loads(p.stdout) if parse else p

    basic = ROOT / "tests/fixtures/basic.lib"
    bad = ROOT / "tests/fixtures/bad-reference.lib"
    query = ["query", basic, "--cell", "INV_X1", "--pin", "Y", "--related", "A",
             "--table", "cell_rise", "--slew", "6e-11", "--load", "1.1e-14", "--json"]
    assert run("inspect", basic, "--json")["cells"] == 2
    assert run("lint", basic, "--json")["errors"] == 0
    assert run("lint", bad, "--json", code=1)["errors"] >= 3
    assert math.isclose(run(*query)["seconds"], 9e-11, rel_tol=1e-12)
    out_of_range = query.copy()
    out_of_range[out_of_range.index("--slew") + 1] = "1e-6"
    assert "OutOfRange" in run(*out_of_range, code=2, parse=False).stderr
    assert run(*out_of_range, "--policy", "clamp")["clamped"]
    assert run(*out_of_range, "--policy", "extrapolate")["extrapolated"]
    assert run("diff", basic, basic, "--json")["total_changes"] == 0
    rows = run("truth", "!(A & B)", "--json")["rows"]
    assert [r["output"] for r in rows] == [True, True, True, False]
    assert run("--version", parse=False).stdout.strip() == "moon-liberty 0.1.0"
    artifacts = ROOT / "artifacts"
    artifacts.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="cli-", dir=artifacts) as tmp:
        target = Path(tmp)
        output = target / "normalized.lib"
        run("normalize", basic, "-o", output, "--json")
        before = hashlib.sha256(output.read_bytes()).hexdigest()
        refused = run("normalize", basic, "-o", output, "--json", code=2, parse=False)
        assert refused.stderr and hashlib.sha256(output.read_bytes()).hexdigest() == before
        run("normalize", basic, "-o", output, "--force", "--json")
        assert run("diff", basic, output, "--json")["total_changes"] == 0
        changed = target / "changed.lib"
        changed.write_text(basic.read_text(encoding="utf-8").replace("area : 2.0", "area : 2.5"), encoding="utf-8")
        difference = run("diff", basic, changed, "--json", code=1)
        assert difference["total_changes"] == 1, difference
        malformed = target / "broken.lib"
        malformed.write_text("library(x){cell(A){", encoding="utf-8")
        failed = run("normalize", malformed, "-o", target / "absent.lib", code=2, parse=False)
        assert failed.stderr and not (target / "absent.lib").exists()
        invalid_utf8 = target / "utf8.lib"
        invalid_utf8.write_bytes(b"\xff\xfe")
        assert run("inspect", invalid_utf8, code=2, parse=False).stderr
        # A malformed integer cannot silently turn into a truncated limit.
        assert run("truth", "A", "--max-inputs", "1.5", code=2, parse=False).stderr

    sources = [p for p in ROOT.rglob("*.mbt") if not any(part in
               {".mooncakes", "_build", ".tools", "artifacts"} for part in p.parts)]
    effective = sum(1 for p in sources for line in p.read_text(encoding="utf-8").splitlines()
                    if line.strip() and not line.lstrip().startswith("//"))
    report = {"cli_assertions": count, "moonbit_files": len(sources),
              "effective_moonbit_lines": effective, "identity_checked": args.identity}
    if args.identity:
        proposal = (ROOT / "PROJECT_APPLICATION.md").read_text(encoding="utf-8")
        module = (ROOT / "moon.mod").read_text(encoding="utf-8")
        readme = (ROOT / "README.md").read_text(encoding="utf-8")
        assert NAME in proposal and REPOSITORY in proposal and len(proposal) <= 2200
        assert not any(old in proposal for old in ["MoonFirmware", "MoonDBC", "moon-firmware", "moon-dbc"])
        assert f'name = "SongYZZZ/moon-liberty"' in module and REPOSITORY in module
        assert NAME in readme and REPOSITORY in readme
        remote = subprocess.run(["git", "remote", "get-url", "origin"], cwd=ROOT,
                                text=True, capture_output=True, check=True).stdout.strip()
        assert remote.removesuffix(".git") == REPOSITORY, remote
        commits = int(subprocess.run(["git", "rev-list", "--count", "HEAD"], cwd=ROOT,
                                    text=True, capture_output=True, check=True).stdout)
        assert commits >= 11, commits
        report["commits"] = commits
    if args.benchmark:
        real = ROOT / "tests/fixtures/ihp-sg13g2-typ.lib"
        samples = []
        for _ in range(7):
            start = time.perf_counter()
            run("inspect", real, "--json")
            samples.append((time.perf_counter() - start) * 1000)
        report["real_inspect_wall_ms_including_process_and_io"] = samples
    (artifacts / "verification.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
