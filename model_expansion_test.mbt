///|
fn multiple_pins() -> @liberty.Library raise @liberty.LibertyError {
  @liberty.load_library(
    "library(x){time_unit:\"1ns\";capacitive_load_unit(1,pf);cell(C){pin(A,B){direction:input;capacitance:0.02;}pin(Y,Z){direction:output;function:\"A & B\";timing(){related_pin:\"A B\";cell_rise(scalar){values(\"0.03\");}}}}}",
  )
}

///|
test "shared scalar pin declarations become individually addressable pins" {
  let library = multiple_pins()
  assert_eq(library.inventory().pins, 4)
  assert_eq(library.cells[0].pins.map(p => p.name), ["A", "B", "Y", "Z"])
  assert_eq(library.cells[0].pin("B").unwrap().capacitance, Some(0.02))
  assert_eq(
    @liberty.lint_library(library).filter(f => f.severity == @liberty.Error),
    [],
  )
}

///|
test "shared output timing declarations can be queried through every alias" {
  let library = multiple_pins()
  for name in ["Y", "Z"] {
    let answer = @liberty.query_timing(
      library, "C", name, "B", "cell_rise", 0.0, 0.0,
    )
    assert_true(answer.seconds.is_close(3.0e-11))
  }
}

///|
test "expansion preserves original syntax and catches duplicate aliases" {
  let library = multiple_pins()
  assert_eq(library.cells[0].pins[0].source.arguments.length(), 2)
  assert_eq(
    @liberty.parse_liberty(@liberty.write_liberty(library.source)).groups(
      "cell",
    )[0]
    .groups("pin")
    .length(),
    2,
  )
  let duplicate = @liberty.load_library(
    "library(x){cell(C){pin(A,A){direction:input;}}}",
  )
  assert_true(
    @liberty.lint_library(duplicate).any(f => f.code == "DuplicatePin"),
  )
}

///|
test "pin expansion budget is combined across the library" {
  let input = "library(x){cell(C){pin(A,B){}}cell(D){pin(C,D){}}}"
  try
    @liberty.load_library(input, model_limits={ max_pins: 3, max_work: 100, })
  catch {
    @liberty.LibertyError(code, _, _) => assert_eq(code, "ModelLimit")
  } noraise {
    _ => fail("per library pin budget ignored")
  }
}

///|
test "shared timing work cannot multiply past the declared budget" {
  let input = "library(x){cell(C){pin(A,B,C,D){timing(){cell_rise(scalar){values(\"1\");}}}}}"
  try
    @liberty.load_library(input, model_limits={ max_pins: 100, max_work: 10, })
  catch {
    @liberty.LibertyError(code, _, _) => assert_eq(code, "ModelLimit")
  } noraise {
    _ => fail("repeated work budget ignored")
  }
}

///|
test "invalid expansion limits never enter model construction" {
  try
    @liberty.load_library("library(x){}", model_limits={
      max_pins: 0,
      max_work: 1,
    })
  catch {
    @liberty.LibertyError(code, _, _) => assert_eq(code, "InvalidLimit")
  } noraise {
    _ => fail("invalid model limit accepted")
  }
}

///|
test "unexpanded vector containers produce an explicit model coverage warning" {
  let library = @liberty.load_library(
    "library(x){cell(C){bus(D){bus_type:word;}bundle(B){members(\"A B\");}}}",
  )
  assert_eq(
    library.findings.filter(f => f.code == "UnexpandedPinContainer").length(),
    2,
  )
  assert_eq(library.source.groups("cell")[0].groups("bus").length(), 1)
}

///|
test "shared pin work accounts for repeated preserved property scans" {
  let input = "library(x){cell(C){pin(A,B,C,D){p1:1;p2:2;p3:3;p4:4;}}}"
  try
    @liberty.load_library(input, model_limits={ max_pins: 100, max_work: 10, })
  catch {
    @liberty.LibertyError(code, _, _) => assert_eq(code, "ModelLimit")
  } noraise {
    _ => fail("shared metadata scan budget ignored")
  }
}
