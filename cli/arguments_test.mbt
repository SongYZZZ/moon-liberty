///|
fn rejected(args : Array[String]) -> String raise {
  try @cli.parse_arguments(args) catch {
    @liberty.LibertyError(code, _, _) => code
  } noraise {
    _ => fail("expected usage rejection")
  }
}

///|
test "CLI help and version need no file access" {
  assert_true(@cli.parse_arguments([]) is Help(""))
  assert_true(@cli.parse_arguments(["--version"]) is Version)
  assert_true(@cli.parse_arguments(["query", "--help"]) is Help("query"))
}

///|
test "CLI rejects unknown commands and options" {
  assert_eq(rejected(["unknown"]), "Usage")
  assert_eq(rejected(["inspect", "x.lib", "--whatever"]), "Usage")
}

///|
test "CLI enforces the exact input count" {
  assert_eq(rejected(["diff", "one.lib"]), "Usage")
  assert_eq(rejected(["inspect", "one.lib", "two.lib"]), "Usage")
}

///|
test "query requires all physical coordinates and object selectors" {
  assert_eq(rejected(["query", "x.lib", "--cell", "A"]), "Usage")
}

///|
test "output is mandatory for write commands" {
  assert_eq(rejected(["normalize", "x.lib"]), "Usage")
  assert_eq(rejected(["extract", "x.lib", "--cells", "A"]), "Usage")
}

///|
test "query options cannot be silently applied to inspect" {
  assert_eq(rejected(["inspect", "x.lib", "--cell", "A"]), "Usage")
}

///|
test "force is limited to explicit write commands" {
  assert_eq(rejected(["inspect", "x.lib", "--force"]), "Usage")
}

///|
test "duplicate output aliases are errors" {
  assert_eq(
    rejected(["normalize", "x.lib", "-o", "a.lib", "--output", "b.lib"]),
    "Usage",
  )
}

///|
test "duplicate flags and values are errors" {
  assert_eq(rejected(["lint", "x.lib", "--json", "--json"]), "Usage")
  assert_eq(
    rejected([
      "diff", "a.lib", "b.lib", "--max-changes", "1", "--max-changes", "2",
    ]),
    "Usage",
  )
}

///|
test "boolean flags do not take equals values" {
  assert_eq(rejected(["inspect", "x.lib", "--json=true"]), "Usage")
}

///|
test "equals syntax and literal paths are accepted" {
  assert_true(
    @cli.parse_arguments(["diff", "--max-changes=2", "--", "-a.lib", "b.lib"])
    is Run(_),
  )
}

///|
test "negative query coordinates are refused" {
  assert_eq(
    rejected([
      "query", "x.lib", "--cell", "A", "--pin", "Y", "--related", "B", "--table",
      "cell_rise", "--slew", "-1", "--load", "1",
    ]),
    "Usage",
  )
}

///|
test "diff report budget must be a bounded positive integer" {
  assert_eq(rejected(["diff", "a.lib", "b.lib", "--max-changes", "0"]), "Usage")
  assert_eq(
    rejected(["diff", "a.lib", "b.lib", "--max-changes", "1.5"]),
    "Usage",
  )
}

///|
test "integer options reject rounded fractions and scientific notation" {
  for
    value in [
      "1.00000000000000001", "1.999999999999999999", "2.0", "1e1", " 2", "+",
    ] {
    assert_eq(rejected(["truth", "A", "--max-inputs", value]), "Usage")
    assert_eq(
      rejected(["diff", "a.lib", "b.lib", "--max-changes", value]),
      "Usage",
    )
  }
  assert_true(
    @cli.parse_arguments(["truth", "A", "--max-inputs", "+02"]) is Run(_),
  )
}

///|
test "truth table budget is explicitly capped" {
  assert_eq(rejected(["truth", "A", "--max-inputs", "17"]), "Usage")
}

///|
test "missing option values cannot consume another option" {
  assert_eq(rejected(["normalize", "a.lib", "-o", "--force"]), "Usage")
}

///|
test "compat and expand require an explicit standard target" {
  assert_eq(rejected(["compat", "x.lib"]), "Usage")
  assert_eq(rejected(["expand", "x.lib", "-o", "x.out"]), "Usage")
}

///|
test "CLI standard options reject unrecognized editions" {
  assert_eq(
    rejected(["compat", "x.lib", "--standard", "latest"]),
    "UnsupportedStandard",
  )
}

///|
test "compat accepts explicit sources while query rejects them" {
  assert_true(
    @cli.parse_arguments([
      "compat", "x.lib", "--standard", "2017.06", "--sources", "sources.json",
    ])
    is Run(_),
  )
  assert_eq(rejected(["inspect", "x.lib", "--standard", "2017.06"]), "Usage")
}

///|
test "expand is an explicit output command and allows force" {
  assert_true(
    @cli.parse_arguments([
      "expand", "x.lib", "--standard", "2017.06", "-o", "expanded.lib", "--force",
    ])
    is Run(_),
  )
  assert_eq(rejected(["expand", "x.lib", "--standard", "2017.06"]), "Usage")
}
