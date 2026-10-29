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

    matrix = json.loads((ROOT / "docs/standards/liberty-2017.06.json").read_text(encoding="utf-8"))
    assert matrix["standard"] == "Liberty 2017.06"
    assert matrix["complete_standard_conformance"] is False
    rows = matrix["rows"]
    assert len({row["id"] for row in rows}) == len(rows)
    for row in rows:
        assert row["status"] in {"partial", "implemented_subset", "preserved_only"}
        assert row["open_items"] and row["evidence"]
        assert all((ROOT / evidence).is_file() for evidence in row["evidence"])
    for material in ("PROJECT_APPLICATION.md", "README.md", "docs/STANDARD_CONFORMANCE.md"):
        assert "2017.06" in (ROOT / material).read_text(encoding="utf-8")
    profile = ["--standard", "2017.06", "--json"]
    shared = FIXTURES / "shared-pins.lib"
    assert run("inspect", shared, "--json")["pins"] == 4
    assert run("lint", shared, "--json")["errors"] == 0
    shared_query = run("query", shared, "--cell", "AND2_DUAL", "--pin", "Z", "--related", "B",
                       "--table", "cell_rise", "--slew", "1e-11", "--load", "1e-15", "--json")
    assert math.isclose(shared_query["seconds"], 3e-11, rel_tol=1e-12)
    rules = json.loads((ROOT / "docs/standards/implemented-rules.json").read_text(encoding="utf-8"))
    assert rules["exhaustive_manual_inventory"] is False
    assert len({r["id"] for r in rules["rules"]}) == len(rules["rules"])
    for rule in rules["rules"]:
        assert rule["reference"] and rule["limitations"]
        assert rule["test"] in (ROOT / rule["evidence"]).read_text(encoding="utf-8")
    source = FIXTURES / "include-main.lib"
    sources = FIXTURES / "sources.json"
    # Merely parsing a newer library date never detects an edition.
    assert run("compat", ROOT / "tests/fixtures/basic.lib", *profile)["target_standard"] == "Liberty 2017.06"
    missing = run("compat", source, *profile, code=2, json_output=False)
    assert "MissingInclude" in missing.stderr
    accepted = run("compat", source, "--sources", sources, *profile)
    assert accepted["implemented_rule_ids"] == [r["id"] for r in rules["rules"]]
    assert accepted["rule_inventory_exhaustive"] is False
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

        # Exercise the new rules through the shipped CLI, not just direct API calls.
        cases = [
            ('define(rank,cell,integer);cell(C){rank(1.5);}', "DefinedAttributeForm"),
            ('type(T){bit_width:4;bit_from:3;downto:true;}cell(C){bus(D){bus_type:T;pin(D[4]){}}}', "StandardBusMember"),
            ('type(T){bit_width:4;bit_from:1;downto:true;}', "StandardBusRange"),
            ('type(T){bit_width:8;}cell(C){bus(D){bus_type:T;pin(D[-1]){}}}', "StandardBusMember"),
            ('lu_table_template(T){}cell(C){pin(Y){timing(){cell_rise(T){values("1");}}}}', "TableShape"),
            ('cell(C){latch(Q,QN){data_in:"0";}}', "StandardStateRequired"),
            ('cell(C){latch(Q,QN){clear:"0";preset:"1";}}', "StandardStateRequired"),
            ('cell(C){ff(Q,QN){clocked_on:"1";}}', "StandardStateRequired"),
            ("cell(C){area:not_a_number;}", "StandardAttributeType"),
            ("pin(A){}", "StandardGroupParent"),
            ("type(T){bit_width:3;bit_from:3;bit_to:0;}", "StandardBusRange"),
            ("cell(C){bus(D){bus_type:missing;}}", "StandardBusType"),
            ("cell(C){ff(Q,Q){}}", "StandardStateArguments"),
            ('cell(C){pin(A){}statetable("A","Q"){table:"X:L:H";}}', "StandardStateTableToken"),
            ('cell(C){pin(Y){timing(){rise_transition(scalar){values("-1");}}}}', "NegativeTransition"),
            ('cell(C){pin(Y){timing(){ocv_std_dev_cell_rise(MISSING){values("1");}}}}', "StandardTemplateReference"),
        ]
        for index, (body, expected) in enumerate(cases):
            case = tmp / f"rule-{index}.lib"
            case.write_text("library(x){" + body + "}", encoding="utf-8")
            report = run("compat", case, *profile, code=1)
            assert expected in {f["code"] for f in report["findings"]}
        sr = tmp / "sr-latch.lib"
        sr.write_text('library(x){cell(C){latch(Q,QN){clear:"0";preset:"1";clear_preset_var1:L;}}}', encoding="utf-8")
        assert run("compat", sr, *profile)["implemented_checks_passed"]

    report = dict(target_standard="Liberty 2017.06", cli_checks=checks,
                  complete_standard_conformance=False, include_and_scalar_query=True,
                  declared_type_rejection=True, advanced_data_preserved=True,
                  unsupported_waveform_evaluation_rejected=True)
    report["implemented_rule_families"] = len(rules["rules"])
    (artifacts / "standard-cases.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
