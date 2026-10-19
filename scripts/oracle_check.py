"""Independent interoperability checks; stdlib only. Never part of the MoonBit package."""
import argparse
import contextlib
import hashlib
import io
import json
import math
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT / "tests/fixtures/ihp-sg13g2-typ.lib"
EXPECTED_SHA256 = "7677a8918689f452e80405ad16a83e744709342574f2aedcc507c2758986b396"
TABLES = {"cell_rise", "cell_fall", "rise_transition", "fall_transition",
          "rise_constraint", "fall_constraint"}
QUERIABLE = TABLES - {"rise_constraint", "fall_constraint"}


def children(group, kind):
    return [child for child in group.get("group", []) if child["type"] == kind]


def unquote(value):
    return value.strip().strip('"')


def numbers(value):
    rows = re.findall(r'"([^"]*)"', value)
    if not rows:
        raise AssertionError("Oracle did not supply a quoted table vector")
    return [[float(number.strip()) for number in row.split(",")] for row in rows]


def snapshot(group):
    # Compare every field, including unsupported vendor fields, without indentation
    # or the reference parser's synthetic traversal indices.
    attrs = {}
    for key, value in group.items():
        if key in {"fatherGroupNum", "depth", "group"}:
            continue
        values = value if isinstance(value, list) else [value]
        attrs[key] = [re.findall(r'"(?:\\.|[^"\\])*"|[(),]|[^\s"(),]+', str(v)) for v in values]
    return attrs, [snapshot(child) for child in group.get("group", [])]


def inventory(group):
    cells = children(group, "cell")
    pins = [p for cell in cells for p in children(cell, "pin")]
    arcs = [t for pin in pins for t in children(pin, "timing")]
    tables = [g for arc in arcs for g in arc.get("group", []) if g["type"] in TABLES]
    return dict(cells=len(cells), pins=len(pins), arcs=len(arcs), tables=len(tables))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--executable", required=True, type=Path)
    args = ap.parse_args()
    exe = args.executable.resolve()
    if hashlib.sha256(FIXTURE.read_bytes()).hexdigest() != EXPECTED_SHA256:
        raise AssertionError("Real fixture has changed")
    sys.path.insert(0, str(ROOT / ".tools/oracle"))
    from libertyParser import libertyParser  # independent GPL-2.0 test process only

    def parse(path):
        captured = io.StringIO()
        with contextlib.redirect_stdout(captured):
            result = libertyParser(str(path)).libDic
        if captured.getvalue():
            raise AssertionError("Reference parser diagnostic: " + captured.getvalue())
        return result

    def run(*argv, expected=0):
        result = subprocess.run([str(exe), *map(str, argv)], cwd=ROOT,
                                text=True, encoding="utf-8", capture_output=True,
                                timeout=30, check=False)
        if result.returncode != expected:
            raise AssertionError((argv, result.returncode, result.stderr, result.stdout))
        return json.loads(result.stdout)

    reference = parse(FIXTURE)
    actual = run("inspect", FIXTURE, "--json")
    counts = inventory(reference)
    assert counts == {key: actual[key] for key in counts}, (counts, actual)
    assert sorted(unquote(c["name"]) for c in children(reference, "cell")) == sorted(actual["cell_names"])
    assert run("lint", FIXTURE, "--json")["errors"] == 0
    # This fixture explicitly declares these scales; do not infer absent units.
    assert unquote(reference["time_unit"]) == "1ns"
    assert reference["capacitive_load_unit"].replace(" ", "") == "(1,pf)"
    assert actual["time_unit_seconds"] == 1e-9
    assert actual["capacitance_unit_farads"] == 1e-12

    templates = {g["name"]: g for g in children(reference, "lu_table_template")}
    checked = 0
    checked_cells = set()
    for cell in children(reference, "cell"):
        before = checked
        for pin in children(cell, "pin"):
            for arc in children(pin, "timing"):
                related = unquote(arc.get("related_pin", ""))
                if (arc.get("timing_type", "combinational") != "combinational"
                        or "when" in arc or len(related.split()) != 1):
                    continue
                for table in arc.get("group", []):
                    if table["type"] not in QUERIABLE:
                        continue
                    template = templates[table["name"]]
                    assert template["variable_1"] == "input_net_transition"
                    assert template["variable_2"] == "total_output_net_capacitance"
                    x = numbers(table.get("index_1", template.get("index_1", "")))[0]
                    y = numbers(table.get("index_2", template.get("index_2", "")))[0]
                    matrix = numbers(table["values"])
                    assert len(matrix) == len(x) and all(len(row) == len(y) for row in matrix)
                    # Independent four-corner weighted sum, at an exact node and an interior point.
                    for wx, wy in [(0.0, 0.0), (0.31, 0.67)]:
                        sx = x[0] * (1 - wx) + x[1] * wx
                        cy = y[0] * (1 - wy) + y[1] * wy
                        expected = sum(matrix[i][j] * a * b
                                       for i, a in enumerate((1 - wx, wx))
                                       for j, b in enumerate((1 - wy, wy))) * 1e-9
                        answer = run("query", FIXTURE, "--cell", unquote(cell["name"]),
                                     "--pin", unquote(pin["name"]), "--related", related,
                                     "--table", table["type"], "--slew", repr(sx * 1e-9),
                                     "--load", repr(cy * 1e-12), "--json")
                        assert math.isclose(answer["seconds"], expected, rel_tol=1e-11, abs_tol=1e-23), (answer, expected)
                        assert not answer["clamped"] and not answer["extrapolated"]
                        checked += 1
        if checked > before:
            checked_cells.add(unquote(cell["name"]))
        if len(checked_cells) >= 12:
            break

    print(f"Independent numeric queries passed: {checked}, cells: {len(checked_cells)}", flush=True)
    assert checked >= 96, checked
    output = ROOT / "artifacts/oracle"
    output.mkdir(parents=True, exist_ok=True)
    normalized = output / "normalized.lib"
    run("normalize", FIXTURE, "-o", normalized, "--force", "--json")
    assert snapshot(reference) == snapshot(parse(normalized)), "Full reference AST changed on normalization"
    assert run("diff", FIXTURE, normalized, "--json")["total_changes"] == 0
    extracted = output / "inv.lib"
    run("extract", FIXTURE, "--cells", "sg13g2_inv_1", "-o", extracted, "--force", "--json")
    subset = parse(extracted)
    assert [unquote(c["name"]) for c in children(subset, "cell")] == ["sg13g2_inv_1"]
    assert snapshot(children(subset, "cell")[0]) == snapshot(next(c for c in children(reference, "cell") if c["name"] == "sg13g2_inv_1"))
    assert len(children(subset, "lu_table_template")) == len(templates)
    assert run("lint", extracted, "--json")["errors"] == 0
    report = dict(oracle="liyanqing1987/libertyParser", revision="77440f598eee8291ddf9393e397711645cf0ee11",
                  fixture_sha256=EXPECTED_SHA256, inventory=counts, query_checks=checked,
                  distinct_cells=len(checked_cells), full_roundtrip=True, extraction=True)
    (output / "report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
