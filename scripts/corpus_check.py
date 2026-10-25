"""Cross-source positive and negative checks; independent parser is test-only."""
import argparse
import hashlib
import json
import math
import re
from pathlib import Path
import subprocess
import sys

from oracle_check import ROOT, children, unquote, numbers, inventory, QUERIABLE


def attribute_text(value):
    if isinstance(value, list):
        return "(" + ",".join(map(str, value)) + ")"
    # The reference reader retains escaped newlines inside strings; these are
    # lexical continuations, which MoonLiberty removes during tokenization.
    return re.sub(r"\\\r?\n", "", str(value))


def as_dictionary(group):
    # Only for counts and numerical selection. Full structural comparison below
    # uses the reader's ordered AST, including repeated attributes and defines.
    result = {a.name: attribute_text(a.value) for a in group.attributes}
    result.update(type=group.group_name, name=",".join(map(str, group.args)),
                  group=[as_dictionary(g) for g in group.groups])
    return result


def structural_snapshot(group):
    return (group.group_name, tuple(map(str, group.args)),
            tuple((a.name, attribute_text(a.value)) for a in group.attributes),
            tuple(map(str, group.defines)),
            tuple(structural_snapshot(g) for g in group.groups))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--executable", required=True, type=Path)
    exe = ap.parse_args().executable.resolve()
    corpus = ROOT / ".tools/corpus"
    manifest = json.loads((ROOT / "docs/standards/corpus.json").read_text(encoding="utf-8"))
    for item in manifest["downloads"]:
        assert hashlib.sha256((corpus / item["file"]).read_bytes()).hexdigest() == item["sha256"], item["file"]
    sys.path.insert(0, str(ROOT / ".tools/corpus-oracle"))
    from liberty.parser import parse_liberty

    def parse(path):
        return parse_liberty(path.read_text(encoding="utf-8"))

    checks = 0

    def run(*args, code=0, json_output=True):
        nonlocal checks
        result = subprocess.run([str(exe), *map(str, args)], cwd=ROOT, text=True,
                                encoding="utf-8", capture_output=True, timeout=60)
        assert result.returncode == code, (args, result.returncode, result.stdout[:2000], result.stderr)
        checks += 1
        return json.loads(result.stdout) if json_output else result

    output = ROOT / "artifacts/corpus"
    output.mkdir(parents=True, exist_ok=True)
    reports = []
    for name in ("nangate45.lib", "yosys-bus.lib", "yosys-dff.lib"):
        source = corpus / name
        reference_ast = parse(source)
        reference = as_dictionary(reference_ast)
        actual = run("inspect", source, "--json")
        expected = inventory(reference)
        assert expected == {key: actual[key] for key in expected}, (name, expected, actual)
        assert run("lint", source, "--json")["errors"] == 0
        compatibility = run("compat", source, "--standard", "2017.06", "--json")
        assert compatibility["implemented_checks_passed"] and not compatibility["complete_standard_conformance"]
        normalized = output / (name + ".normalized.lib")
        run("normalize", source, "-o", normalized, "--force", "--json")
        assert structural_snapshot(reference_ast) == structural_snapshot(parse(normalized)), (name, "independent full AST changed")
        assert run("diff", source, normalized, "--json")["total_changes"] == 0
        reports.append(dict(file=name, inventory=expected, independent_full_roundtrip=True,
                            compat_errors=compatibility["errors"], compat_warnings=compatibility["warnings"]))

    # Original missing semicolons are not repaired or counted as accepted libraries.
    for name in ("asap7-invbuf.lib", "asap7-seq.lib"):
        rejected = run("compat", corpus / name, "--standard", "2017.06", "--json", code=2, json_output=False)
        assert "MissingSemicolon" in rejected.stderr
        reports.append(dict(file=name, expected_rejection="MissingSemicolon", original_bytes_unchanged=True))

    # Different source and capacitance unit from the existing IHP oracle suite.
    source = corpus / "nangate45.lib"
    reference = as_dictionary(parse(source))
    assert unquote(reference["time_unit"]) == "1ns"
    assert reference["capacitive_load_unit"].replace(" ", "") == "(1,ff)"
    templates = {g["name"]: g for g in children(reference, "lu_table_template")}
    queries = 0
    checked_cells = set()
    for cell in children(reference, "cell"):
        before = queries
        for pin in children(cell, "pin"):
            for arc in children(pin, "timing"):
                related = unquote(arc.get("related_pin", ""))
                if arc.get("timing_type", "combinational") != "combinational" or "when" in arc or len(related.split()) != 1:
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
                    for wx, wy in ((0.0, 0.0), (0.37, 0.59)):
                        sx = x[0] * (1 - wx) + x[1] * wx
                        cy = y[0] * (1 - wy) + y[1] * wy
                        expected = sum(matrix[i][j] * a * b
                                       for i, a in enumerate((1 - wx, wx))
                                       for j, b in enumerate((1 - wy, wy))) * 1e-9
                        answer = run("query", source, "--cell", unquote(cell["name"]), "--pin", unquote(pin["name"]),
                                     "--related", related, "--table", table["type"], "--slew", repr(sx * 1e-9),
                                     "--load", repr(cy * 1e-15), "--json")
                        assert math.isclose(answer["seconds"], expected, rel_tol=1e-11, abs_tol=1e-23), (answer, expected)
                        assert not answer["clamped"] and not answer["extrapolated"]
                        queries += 1
        if queries > before:
            checked_cells.add(unquote(cell["name"]))
        if len(checked_cells) >= 4:
            break
    assert queries >= 32 and len(checked_cells) >= 4, queries
    report = dict(corpus=reports, cli_checks=checks, independent_queries=queries,
                  numeric_source="nangate45.lib", numeric_cells=len(checked_cells),
                  complete_standard_conformance=False)
    (output / "report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2), flush=True)


if __name__ == "__main__":
    main()
