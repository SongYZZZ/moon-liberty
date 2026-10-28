///|
test "quoted numeric signals retain identity in Boolean formatting" {
  for text in ["\"0\"", "\"1\"", "\"1A\" & B", "\"A+B\" | A"] {
    let expression = @liberty.parse_logic(text)
    assert_eq(
      @liberty.parse_logic(@liberty.format_logic(expression)),
      expression,
    )
  }
}

///|
test "Boolean formatter rejects caller names that inject an expression" {
  for name in ["", "A\" | B | \"C", "A\nB"] {
    try @liberty.format_logic(@liberty.Signal(name)) catch {
      @liberty.LibertyError(code, _, _) => assert_eq(code, "InvalidLogicAst")
    } noraise {
      _ => fail("unrepresentable signal accepted")
    }
  }
}

///|
test "semantic comparison distinguishes numeric named pin from constant" {
  let before = @liberty.load_library(
    "library(x){cell(C){pin(0){direction:input;}pin(Y){direction:output;function:\"\\\"0\\\"\";}}}",
  )
  let after = @liberty.load_library(
    "library(x){cell(C){pin(0){direction:input;}pin(Y){direction:output;function:\"0\";}}}",
  )
  assert_eq(@liberty.compare_libraries(before, after).total_changes, 1)
}

///|
test "finite opposite extreme endpoints interpolate without false overflow" {
  let t = table([0.0, 1.0], [], [-1.0e308, 1.0e308])
  assert_eq(@liberty.lookup_table(t, 0.0).value, -1.0e308)
  assert_eq(@liberty.lookup_table(t, 0.5).value, 0.0)
  assert_eq(@liberty.lookup_table(t, 1.0).value, 1.0e308)
}

///|
test "large finite axis span has the right interpolation weight" {
  let t = table([-1.0e308, 1.0e308], [], [2.0, 4.0])
  assert_eq(@liberty.lookup_table(t, 0.0).value, 3.0)
  assert_true(@liberty.lookup_table(t, 5.0e307).value.is_close(3.5))
}

///|
test "opposite extreme endpoints support representable small extrapolation" {
  let t = table([0.0, 1.0], [], [-1.0e308, 9.0e307])
  let value = @liberty.lookup_table(t, 1.01, policy=@liberty.Extrapolate).value
  assert_true(value.is_close(9.19e307, relative_tolerance=1.0e-14))
}

///|
test "truly unrepresentable interpolation is still rejected" {
  let t = table([0.0, 1.0], [], [-1.0e308, 1.0e308])
  try @liberty.lookup_table(t, 2.0, policy=@liberty.Extrapolate) catch {
    @liberty.LibertyError(code, _, _) => assert_eq(code, "NumericRange")
  } noraise {
    _ => fail("nonfinite extrapolation accepted")
  }
}

///|
test "SI prefixes cannot be silently lowercased into a different magnitude" {
  for text in ["1MV", "1MF", "1MS"] {
    try
      @liberty.parse_unit(
        text,
        if text.has_suffix("V") {
          @liberty.Voltage
        } else if text.has_suffix("F") {
          @liberty.Capacitance
        } else {
          @liberty.Time
        },
      )
    catch {
      @liberty.LibertyError(_, _, _) => ()
    } noraise {
      _ => fail("unsupported upper case SI prefix changed magnitude")
    }
  }
  assert_eq(@liberty.parse_unit("1mV", @liberty.Voltage), 0.001)
  assert_eq(@liberty.parse_unit("1pF", @liberty.Capacitance), 1.0e-12)
}

///|
test "caller supplied unit scales are revalidated before scalar SI queries" {
  let source = @liberty.load_library(
    "library(x){time_unit:\"1ns\";capacitive_load_unit(1,pf);cell(C){pin(A){direction:input;}pin(Y){direction:output;timing(){related_pin:\"A\";cell_rise(scalar){values(\"1\");}}}}}",
  )
  for time in [0.0, -1.0, @double.infinity, @double.not_a_number] {
    let library = {
      ..source,
      units: Some({
        time_seconds: time,
        capacitance_farads: 1.0e-12,
        voltage_volts: None,
      }),
    }
    assert_true(
      @liberty.lint_library(library).any(f => f.code == "InvalidUnit"),
    )
    try
      @liberty.query_timing(library, "C", "Y", "A", "cell_rise", 0.0, 0.0)
    catch {
      @liberty.LibertyError(code, _, _) => assert_eq(code, "InvalidLibrary")
    } noraise {
      _ => fail("invalid public scale used")
    }
  }
}

///|
test "inherited third axis is never silently dropped by the evaluator" {
  let root = @liberty.parse_liberty(
    "library(x){lu_table_template(T){index_1(\"1\");index_2(\"2\");index_3(\"3\");}cell_rise(T){values(\"4\");}}",
  )
  try
    @liberty.read_table(
      root.groups("cell_rise")[0],
      template=root.groups("lu_table_template")[0],
    )
  catch {
    @liberty.LibertyError(code, _, _) => assert_eq(code, "UnsupportedDimension")
  } noraise {
    _ => fail("inherited 3D evaluated as 2D")
  }
}

///|
test "malformed three dimensional table is an error rather than an unsupported warning" {
  let library = @liberty.load_library(
    "library(x){lu_table_template(T){index_1(\"1,2\");index_2(\"1,2\");index_3(\"1,2\");}cell(C){pin(Y){timing(){cell_rise(T){values(\"1,2\");}}}}}",
  )
  assert_true(
    library.findings.any(f => {
      f.code == "TableShape" && f.severity == @liberty.Error
    }),
  )
}

///|
test "finite slope extrapolation avoids intermediate product overflow" {
  for
    sample in [
      (-1.0e308, 0.0, 2.0, 1.0e308),
      (1.0e308, 0.0, 2.0, -1.0e308),
      (1.0e308, 1.5e308, -4.0, -1.0e308),
      (-1.0e308, -1.5e308, -4.0, 1.0e308),
      (-1.5e308, -1.4e308, 20.0, 5.0e307),
    ] {
    let t = table([0.0, 1.0], [], [sample.0, sample.1])
    let answer = @liberty.lookup_table(t, sample.2, policy=@liberty.Extrapolate)
    assert_true(answer.value.is_close(sample.3, relative_tolerance=1.0e-13))
    assert_true(answer.extrapolated)
  }
}

///|
test "bilinear lookup shares overflow safe extrapolation" {
  let t = table([0.0, 1.0], [0.0, 1.0], [-1.0e308, -1.0e308, 0.0, 0.0])
  let answer = @liberty.lookup_table(t, 2.0, y=0.5, policy=@liberty.Extrapolate)
  assert_true(answer.value.is_close(1.0e308, relative_tolerance=1.0e-14))
  assert_true(answer.extrapolated)
}
