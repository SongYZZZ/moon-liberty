"""Reproduce the 2017.06 format/evaluation boundary cases without extra dependencies."""
import argparse
import json
import math
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / "tests/fixtures/liberty2017"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--executable", required=True, type=Path)
    exe = parser.parse_args().executable.resolve()
    checks = 0

    def run(*args, code=0, json_output=True):
        nonlocal checks
        result = subprocess.run([str(exe), *map(str, args)], cwd=ROOT, text=True,
                                encoding="utf-8", capture_output=True, timeout=30)
        assert result.returncode == code, (args, result.returncode, result.stdout, result.stderr)
        checks += 1
        return json.loads(result.stdout) if json_output else result

    profile = ["--standard", "2017.06", "--json"]
    source = FIXTURES / "include-main.lib"
    sources = FIXTURES / "sources.json"
    # Merely parsing a newer library date never detects an edition.
    assert run("compat", ROOT / "tests/fixtures/basic.lib", *profile)["target_standard"] == "Liberty 2017.06"
    missing = run("compat", source, *profile, code=2, json_output=False)
    assert "MissingInclude" in missing.stderr
    accepted = run("compat", source, "--sources", sources, *profile)
    assert accepted["implemented_checks_passed"] and accepted["roundtrip_verified"]
    assert accepted["complete_standard_conformance"] is False

    artifacts = ROOT / "artifacts"
    artifacts.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="standard-", dir=artifacts) as tmp:
        tmp = Path(tmp)
        expanded = tmp / "expanded.lib"
        run("expand", source, "--sources", sources, *profile, "-o", expanded)
        assert "include_file" not in expanded.read_text(encoding="utf-8")
        assert run("lint", expanded, "--json")["errors"] == 0
        answer = run("query", expanded, "--cell", "INV_X1", "--pin", "Y", "--related", "A",
                     "--table", "cell_rise", "--slew", "1e-11", "--load", "1e-15", "--json")
        assert math.isclose(answer["seconds"], 2.5e-11, rel_tol=1e-12)
        bad_type = run("compat", FIXTURES / "declared-types-bad.lib", *profile, code=1)
        assert not bad_type["implemented_checks_passed"] and bad_type["errors"] == 1
        assert "DefinedAttributeType" in json.dumps(bad_type)

        advanced = FIXTURES / "preserve-models.lib"
        preserved = run("compat", advanced, *profile)
        assert preserved["roundtrip_verified"] and not preserved["complete_standard_conformance"]
        coverage = {f["family"]: f["evaluation"] for f in preserved["features"]}
        for family in ("bus_bundle", "sequential", "variation_lvf", "current_waveform", "power"):
            assert coverage[family] == "preserved_only"
        normalized = tmp / "models.lib"
        run("normalize", advanced, "-o", normalized, "--json")
        rendered = normalized.read_text(encoding="utf-8")
        for field in ("ocv_mean_shift_cell_rise", "output_current_rise", "index_3",
                      "ff (", "bus (", "bundle (", "audit_metadata", "internal_power"):
            assert field in rendered, field
        assert run("diff", advanced, normalized, "--json")["total_changes"] == 0
        refused = run("query", advanced, "--cell", "DFF_BUS", "--pin", "Q", "--related", "CK",
                      "--table", "output_current_rise", "--slew", "1e-11", "--load", "1e-15",
                      code=2, json_output=False)
        assert "UnsupportedTableKind" in refused.stderr or "Unsupported" in refused.stderr
        invalid_map = tmp / "bad-map.json"
        invalid_map.write_text('{"pins.inc": 123}', encoding="utf-8")
        assert run("compat", source, "--sources", invalid_map, *profile, code=2, json_output=False).stderr
        nested_map = tmp / "nested-map.json"
        nested_map.write_text(json.dumps({"pins.inc": "include_file(other.inc);"}), encoding="utf-8")
        assert "NestedInclude" in run("compat", source, "--sources", nested_map, *profile, code=2, json_output=False).stderr

    report = dict(target_standard="Liberty 2017.06", cli_checks=checks,
                  complete_standard_conformance=False, include_and_scalar_query=True,
                  declared_type_rejection=True, advanced_data_preserved=True,
                  unsupported_waveform_evaluation_rejected=True)
    (artifacts / "standard-cases.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
