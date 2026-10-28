"""Independent decimal oracle and end-to-end invariants for the daily audit."""
import argparse
from decimal import Decimal, localcontext
import json
import math
from pathlib import Path
import random
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--executable", required=True, type=Path)
    exe = parser.parse_args().executable.resolve()
    calls = 0

    def run(*args, code=0):
        nonlocal calls
        result = subprocess.run([str(exe), *map(str, args)], cwd=ROOT, text=True,
                                encoding="utf-8", capture_output=True, timeout=30)
        calls += 1
        assert result.returncode == code, (args, result.returncode, result.stdout[:1500], result.stderr)
        return json.loads(result.stdout)

    artifacts = ROOT / "artifacts"
    artifacts.mkdir(exist_ok=True)
    numeric_checks = 0
    with tempfile.TemporaryDirectory(prefix="invariants-", dir=artifacts) as directory:
        directory = Path(directory)

        def fixture(name, body):
            path = directory / name
            path.write_text("library(x){" + body + "}", encoding="utf-8")
            return path

        before = fixture("before.lib", 'cell(C){pin(0){direction:input;}pin(Y){direction:output;function:"\\\"0\\\"";}}')
        after = fixture("after.lib", 'cell(C){pin(0){direction:input;}pin(Y){direction:output;function:"0";}}')
        assert run("diff", before, after, "--json", code=1)["total_changes"] == 1
        assert [r["output"] for r in run("truth", '"0"', "--json")["rows"]] == [False, True]

        shared = ROOT / "tests/fixtures/liberty2017/shared-pins.lib"
        selected = directory / "selected.lib"
        run("extract", shared, "--cells", "AND2_DUAL", "-o", selected, "--json")
        assert run("inspect", selected, "--json")["pins"] == 4
        assert run("diff", shared, selected, "--json")["total_changes"] == 0

        local = fixture("local.lib", 'cell(C){type(W){bit_width:2;bit_from:4;bit_to:5;}bus(D){bus_type:W;pin(D[4]){}}}')
        assert run("compat", local, "--standard", "2017.06", "--json")["implemented_checks_passed"]
        bad = fixture("bad-local.lib", local.read_text().removeprefix("library(x){").removesuffix("}").replace("D[4]", "D[7]"))
        assert "StandardBusMember" in {f["code"] for f in run("compat", bad, "--standard", "2017.06", "--json", code=1)["findings"]}

        incomplete = fixture("incomplete.lib", 'cell(C){ff(Q,QN){clocked_on:"1";}}')
        assert "StandardStateRequired" in {f["code"] for f in run("compat", incomplete, "--standard", "2017.06", "--json", code=1)["findings"]}

        states = fixture("state-names.lib", 'time_unit:"1ns";capacitive_load_unit(1,pf);cell(C){pin(A){direction:input;}'
                         'statetable("A","IQ"){table:"L:-:L,H:-:H";}pin(Y){direction:output;function:"IQ";}}')
        assert run("compat", states, "--standard", "2017.06", "--json")["implemented_checks_passed"]
        assert run("lint", states, "--json")["errors"] == 0

        # Scope resolution should not copy every global type into every cell.
        scoped = fixture("scopes.lib", "".join(f"type(T{i}){{bit_width:1;}}" for i in range(2048)) +
                         "".join(f"cell(C{i}){{type(W){{bit_width:1;}}bus(D){{bus_type:W;pin(D[0]){{}}}}}}" for i in range(2048)))
        started = time.perf_counter()
        assert run("compat", scoped, "--standard", "2017.06", "--json")["implemented_checks_passed"]
        scoped_wall_ms = (time.perf_counter() - started) * 1000

        rng = random.Random(20261026)
        samples = [(-1e308, 1e308, 0.0), (-1e308, 1e308, 0.5),
                   (-1e308, 1e308, 1.0), (-1e308, 9e307, 1.01),
                   (-1e308, 0.0, 2.0), (1e308, 0.0, 2.0),
                   (-1.5e308, -1.4e308, 20.0)]
        for _ in range(48):
            exponent = rng.randint(-280, 300)
            samples.append((rng.uniform(-1, 1) * 10.0 ** exponent,
                            rng.uniform(-1, 1) * 10.0 ** exponent, rng.random()))
        for index, (a, b, x) in enumerate(samples):
            path = fixture(f"numeric-{index}.lib", 'delay_model:table_lookup;time_unit:"1s";capacitive_load_unit(1,f);'
                           'lu_table_template(T){variable_1:input_net_transition;index_1("0,1");}'
                           'cell(C){pin(A){direction:input;}pin(Y){direction:output;timing(){related_pin:"A";'
                           f'cell_rise(T){{values("{a!r},{b!r}");}}}}}}}}')
            with localcontext() as context:
                context.prec = 100
                da, db, dx = map(Decimal.from_float, (a, b, x))
                expected = float(da * (1 - dx) + db * dx)
            answer = run("query", path, "--cell", "C", "--pin", "Y", "--related", "A",
                         "--table", "cell_rise", "--slew", repr(x), "--load", "0",
                         "--policy", "extrapolate", "--json")
            assert math.isclose(answer["seconds"], expected, rel_tol=5e-13, abs_tol=1e-300), (index, answer, expected)
            numeric_checks += 1

    report = dict(seed=20261026, cli_checks=calls, decimal_oracle_queries=numeric_checks,
                  quoted_pin_identity=True, shared_pin_extraction=True,
                  local_type_scope=True, incomplete_state_rejected=True,
                  statetable_internal_references=True,
                  scoped_workload=dict(library_types=2048, cells=2048, wall_ms_including_process_and_io=scoped_wall_ms),
                  complete_standard_conformance=False)
    (artifacts / "invariant-audit.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
