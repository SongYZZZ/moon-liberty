///|
fn small_library() -> @liberty.Library raise {
  @liberty.load_library(
    "library(test){time_unit:\"1ns\";capacitive_load_unit(1,pf);lu_table_template(T){variable_1:input_net_transition;variable_2:total_output_net_capacitance;index_1(\"1,3\");index_2(\"2,4\");}cell(INV){area:2;pin(A){direction:input;capacitance:0.01;}pin(Y){direction:output;function:\"!A\";timing(){related_pin:\"A\";timing_type:combinational;timing_sense:negative_unate;cell_rise(T){values(\"1,2\",\"3,4\");}}}}}",
  )
}

///|
test "typed library inventories actual cells pins arcs and tables" {
  let library = small_library()
  let inventory = library.inventory()
  assert_eq(inventory.cells, 1)
  assert_eq(inventory.pins, 2)
  assert_eq(inventory.arcs, 1)
  assert_eq(inventory.tables, 1)
  assert_eq(inventory.errors, 0)
}

///|
test "typed cell and pin lookups are case sensitive" {
  let library = small_library()
  assert_true(library.cell("INV") is Some(_))
  assert_true(library.cell("inv") is None)
  assert_true(library.cell("INV").unwrap().pin("A") is Some(_))
}

///|
test "cell area and input capacitance remain numeric" {
  let cell = small_library().cell("INV").unwrap()
  assert_eq(cell.area, Some(2.0))
  assert_eq(cell.pin("A").unwrap().capacitance, Some(0.01))
}

///|
test "timing metadata and functions are retained" {
  let pin = small_library().cell("INV").unwrap().pin("Y").unwrap()
  assert_eq(pin.function, Some("!A"))
  assert_eq(pin.timings[0].related_pins, ["A"])
  assert_eq(pin.timings[0].timing_sense, Some("negative_unate"))
}

///|
test "model reports malformed numbers without inventing numeric zeros" {
  let library = @liberty.load_library("library(x){cell(A){area:not_a_number;}}")
  assert_eq(library.cells[0].area, None)
  assert_true(library.findings.any(f => f.code == "InvalidNumber"))
}

///|
test "missing units permit syntax inspection while recording a warning" {
  let library = @liberty.load_library("library(x){cell(A){}}")
  assert_eq(library.units, None)
  assert_true(
    library.findings.any(f => f.code == "MissingUnit" && f.severity is Warning),
  )
}

///|
test "unknown lookup templates produce model errors" {
  let library = @liberty.load_library(
    "library(x){cell(A){pin(Y){timing(){cell_rise(missing){values(\"1\");}}}}}",
  )
  assert_true(
    library.findings.any(f => f.code == "MissingTemplate" && f.severity is Error),
  )
}

///|
test "duplicate template names cannot silently choose the last definition" {
  let library = @liberty.load_library(
    "library(x){lu_table_template(T){}lu_table_template(T){}}",
  )
  assert_true(library.findings.any(f => f.code == "DuplicateTemplate"))
}

///|
test "scalar timing models do not need an explicit scalar template" {
  let library = @liberty.load_library(
    "library(x){cell(A){pin(Y){timing(){cell_rise(scalar){values(\"0.1\");}}}}}",
  )
  assert_eq(library.inventory().tables, 1)
}

///|
test "multiple related pins are retained for cross reference checking" {
  let library = @liberty.load_library(
    "library(x){cell(A){pin(Y){timing(){related_pin:\"A B\";}}}}",
  )
  assert_eq(library.cells[0].pins[0].timings[0].related_pins, ["A", "B"])
}

///|
test "conditioned arcs retain their explicit when condition" {
  let library = @liberty.load_library(
    "library(x){cell(A){pin(Y){timing(){when:\"EN\";}}}}",
  )
  assert_eq(library.cells[0].pins[0].timings[0].condition, Some("EN"))
}

///|
test "unrecognized groups remain available through the source AST" {
  let library = @liberty.load_library(
    "library(x){extension(V){k:5;}cell(A){pg_pin(VDD){voltage_name:VDD;}}}",
  )
  assert_eq(library.source.groups("extension").length(), 1)
  assert_eq(library.cells[0].source.groups("pg_pin").length(), 1)
}

///|
test "unsupported 3D tables are visible as warnings and remain in the AST" {
  let library = @liberty.load_library(
    "library(x){lu_table_template(T){variable_3:unknown;}cell(A){pin(Y){timing(){cell_rise(T){index_3(\"1\");values(\"1\");}}}}}",
  )
  assert_true(
    library.findings.any(f => {
      f.code == "UnsupportedDimension" && f.severity is Warning
    }),
  )
  assert_eq(
    library.cells[0].pins[0].source.groups("timing")[0]
    .groups("cell_rise")
    .length(),
    1,
  )
}
