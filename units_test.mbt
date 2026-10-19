///|
fn near(actual : Double, expected : Double) -> Unit raise {
  assert_true(
    actual.is_close(
      expected,
      relative_tolerance=1.0e-12,
      absolute_tolerance=1.0e-30,
    ),
  )
}

///|
fn unit_error(text : String, kind : @liberty.Quantity) -> String raise {
  try @liberty.parse_unit(text, kind) catch {
    @liberty.LibertyError(code, _, _) => code
  } noraise {
    _ => fail("expected unit rejection")
  }
}

///|
test "nanosecond and picosecond units normalize to seconds" {
  near(@liberty.parse_unit("1ns", Time), 1.0e-9)
  near(@liberty.parse_unit("10ps", Time), 1.0e-11)
}

///|
test "millisecond microsecond and femtosecond units normalize" {
  near(@liberty.parse_unit("1ms", Time), 1.0e-3)
  near(@liberty.parse_unit("1us", Time), 1.0e-6)
  near(@liberty.parse_unit("1fs", Time), 1.0e-15)
}

///|
test "scientific unit multipliers retain the exponent" {
  near(@liberty.parse_unit("1e-3ns", Time), 1.0e-12)
}

///|
test "capacitance prefixes do not get confused with time units" {
  near(@liberty.parse_unit("1pf", Capacitance), 1.0e-12)
  near(@liberty.parse_unit("10ff", Capacitance), 1.0e-14)
}

///|
test "voltage prefixes normalize independently" {
  near(@liberty.parse_unit("1200mV", Voltage), 1.2)
}

///|
test "negative unit scales are refused" {
  assert_eq(unit_error("-1ns", Time), "InvalidUnit")
}

///|
test "zero unit scales are refused" {
  assert_eq(unit_error("0pf", Capacitance), "InvalidUnit")
}

///|
test "wrong dimensions cannot silently pass unit parsing" {
  assert_eq(unit_error("1pf", Time), "UnsupportedUnit")
  assert_eq(unit_error("1ns", Capacitance), "UnsupportedUnit")
}

///|
test "unit suffix without a numeric factor is refused" {
  assert_eq(unit_error("ns", Time), "InvalidNumber")
}

///|
test "overflowing unit multipliers are refused" {
  assert_eq(unit_error("1e999ns", Time), "InvalidNumber")
}

///|
test "numeric parsing supports negative scientific values" {
  near(@liberty.finite_number("-1.25e-3"), -0.00125)
}

///|
test "nonfinite numeric spellings never enter timing arithmetic" {
  for value in ["nan", "NaN", "inf", "-inf", "1e999"] {
    try @liberty.finite_number(value) catch {
      @liberty.LibertyError(code, _, _) =>
        assert_true(code == "NonFiniteNumber" || code == "InvalidNumber")
    } noraise {
      _ => fail("nonfinite number accepted")
    }
  }
}

///|
test "empty and trailing numeric garbage are refused" {
  for value in ["", " ", "1abc", "--2", "1e"] {
    try @liberty.finite_number(value) catch {
      @liberty.LibertyError(code, _, _) => assert_eq(code, "InvalidNumber")
    } noraise {
      _ => fail("invalid number accepted")
    }
  }
}

///|
test "library units use complex capacitance and simple time syntax" {
  let root = @liberty.parse_liberty(
    "library(x){time_unit:\"1ns\";capacitive_load_unit(1,pf);voltage_unit:\"1V\";}",
  )
  let units = @liberty.read_units(root)
  near(units.time_seconds, 1.0e-9)
  near(units.capacitance_farads, 1.0e-12)
  assert_eq(units.voltage_volts, Some(1.0))
}

///|
test "missing unit declarations cannot become guessed scales" {
  let root = @liberty.parse_liberty("library(x){}")
  try @liberty.read_units(root) catch {
    @liberty.LibertyError(code, _, _) => assert_eq(code, "MissingUnit")
  } noraise {
    _ => fail("missing units guessed")
  }
}

///|
test "malformed capacitance declarations are refused" {
  let root = @liberty.parse_liberty(
    "library(x){time_unit:\"1ns\";capacitive_load_unit(pf);}",
  )
  try @liberty.read_units(root) catch {
    @liberty.LibertyError(code, _, _) => assert_eq(code, "MissingUnit")
  } noraise {
    _ => fail("malformed unit accepted")
  }
}

///|
test "comma separated numeric rows preserve signs and exponents" {
  assert_eq(@liberty.number_list([@liberty.Text("1, -2, 3e-3")]), [
    1.0, -2.0, 0.003,
  ])
}

///|
test "empty entries in a numeric row are errors" {
  try @liberty.number_list([@liberty.Text("1,,2")]) catch {
    @liberty.LibertyError(code, _, _) => assert_eq(code, "InvalidNumber")
  } noraise {
    _ => fail("empty entry accepted")
  }
}

///|
test "numeric row expressions cannot be silently concatenated" {
  try
    @liberty.number_list([
      @liberty.Word("1"),
      @liberty.Word("+"),
      @liberty.Word("2"),
    ])
  catch {
    @liberty.LibertyError(code, _, _) => assert_eq(code, "ExpectedNumbers")
  } noraise {
    _ => fail("expression accepted as number")
  }
}
