///|
fn query_error(
  library : @liberty.Library,
  cell~ : String = "INV",
  pin~ : String = "Y",
  related~ : String = "A",
  kind~ : String = "cell_rise",
  slew~ : Double = 2.0e-9,
  load~ : Double = 3.0e-12,
  condition? : String,
) -> String raise {
  try
    @liberty.query_timing(
      library,
      cell,
      pin,
      related,
      kind,
      slew,
      load,
      condition?,
    )
  catch {
    @liberty.LibertyError(code, _, _) => code
  } noraise {
    _ => fail("expected timing query rejection")
  }
}

///|
test "malformed named tables cannot bypass SI range checks as scalar" {
  let library = @liberty.load_library(
    "library(x){time_unit:\"1ns\";capacitive_load_unit(1,pf);lu_table_template(T){}cell(INV){pin(A){direction:input;}pin(Y){direction:output;timing(){related_pin:\"A\";cell_rise(T){values(\"1\");}}}}}",
  )
  assert_eq(query_error(library), "InvalidLibrary")
}

///|
test "SI query converts both coordinates and the delay result" {
  let query = @liberty.query_timing(
    small_library(),
    "INV",
    "Y",
    "A",
    "cell_rise",
    2.0e-9,
    3.0e-12,
  )
  near(query.seconds, 2.5e-9)
  near(query.raw_value, 2.5)
}

///|
test "reversed template axes are mapped by variable names" {
  let library = @liberty.load_library(
    "library(x){time_unit:\"1ns\";capacitive_load_unit(1,pf);lu_table_template(T){variable_1:total_output_net_capacitance;variable_2:input_net_transition;index_1(\"2,4\");index_2(\"1,3\");}cell(INV){pin(A){direction:input;}pin(Y){direction:output;timing(){related_pin:\"A\";cell_rise(T){values(\"1,2\",\"3,4\");}}}}}",
  )
  near(
    @liberty.query_timing(
      library, "INV", "Y", "A", "cell_rise", 1.0e-9, 4.0e-12,
    ).seconds,
    3.0e-9,
  )
}

///|
test "missing cells pins and arcs have distinct diagnostics" {
  assert_eq(query_error(small_library(), cell="NO"), "MissingCell")
  assert_eq(query_error(small_library(), pin="NO"), "MissingPin")
  assert_eq(query_error(small_library(), related="Y"), "MissingArc")
}

///|
test "negative physical query coordinates are refused even before interpolation" {
  assert_eq(query_error(small_library(), slew=-1.0), "InvalidCoordinate")
  assert_eq(query_error(small_library(), load=-1.0), "InvalidCoordinate")
}

///|
test "missing physical unit declarations prevent SI queries" {
  let library = @liberty.load_library(
    "library(x){cell(INV){pin(A){direction:input;}pin(Y){direction:output;timing(){related_pin:\"A\";cell_rise(scalar){values(\"1\");}}}}}",
  )
  assert_eq(query_error(library), "MissingUnit")
}

///|
test "queries refuse semantically invalid libraries" {
  let library = @liberty.load_library("library(x){cell(INV){area:-1;}}")
  assert_eq(query_error(library), "InvalidLibrary")
}

///|
test "out of range is refused by default after unit conversion" {
  assert_eq(query_error(small_library(), slew=0.0), "OutOfRange")
}

///|
test "clamped physical queries report their policy" {
  let query = @liberty.query_timing(
    small_library(),
    "INV",
    "Y",
    "A",
    "cell_rise",
    0.0,
    3.0e-12,
    policy=Clamp,
  )
  near(query.seconds, 1.5e-9)
  assert_true(query.clamped)
}

///|
test "constraint tables cannot be queried as combinational delays" {
  assert_eq(
    query_error(small_library(), kind="rise_constraint"),
    "UnsupportedQuery",
  )
}

///|
test "conditional arcs require an exact condition selector" {
  let source = @liberty.write_liberty(small_library().source)
  let library = @liberty.load_library(
    source.replace(
      old="related_pin : \"A\";",
      new="related_pin : \"A\"; when : \"A\";",
    ),
  )
  assert_eq(query_error(library), "ConditionRequired")
  assert_eq(query_error(library, condition="!A"), "MissingCondition")
  near(
    @liberty.query_timing(
      library,
      "INV",
      "Y",
      "A",
      "cell_rise",
      2.0e-9,
      3.0e-12,
      condition="A",
    ).seconds,
    2.5e-9,
  )
}

///|
test "duplicate matching tables cannot be selected arbitrarily" {
  let library = small_library()
  let pin = library.cells[0].pins[1]
  pin.timings.push(pin.timings[0])
  assert_eq(query_error(library), "AmbiguousArc")
}

///|
test "an unsupported axis does not receive an assumed physical dimension" {
  let source = @liberty.write_liberty(small_library().source)
  let library = @liberty.load_library(
    source.replace(old="input_net_transition", new="unrecognized_axis"),
  )
  assert_eq(query_error(library), "UnsupportedAxis")
}
