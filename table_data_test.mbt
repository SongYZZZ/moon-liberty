///|
fn format_table(
  body : String,
  template : String,
) -> @liberty.TableData raise @liberty.LibertyError {
  let root = @liberty.parse_liberty(
    "library(x){" + template + "cell_rise(T){" + body + "}}",
  )
  @liberty.read_table_data(
    root.groups("cell_rise")[0],
    template?=root.groups("lu_table_template").get(0),
  )
}

///|
test "three dimensional format data uses index three for each row" {
  let data = format_table(
    "values(\"1,2,3\",\"4,5,6\",\"7,8,9\",\"10,11,12\");", "lu_table_template(T){index_1(\"1,2\");index_2(\"3,4\");index_3(\"5,6,7\");}",
  )
  assert_eq(data.axes.length(), 3)
  assert_eq(data.rows[3], [10.0, 11.0, 12.0])
}

///|
test "three dimensional format rejects correct total count in transposed rows" {
  try
    format_table(
      "values(\"1,2,3,4\",\"5,6,7,8\",\"9,10,11,12\");", "lu_table_template(T){index_1(\"1,2\");index_2(\"3,4\");index_3(\"5,6,7\");}",
    )
  catch {
    @liberty.LibertyError(code, _, _) => assert_eq(code, "TableShape")
  } noraise {
    _ => fail("transposed 3D rows accepted")
  }
}

///|
test "format reader rejects missing intermediate axes" {
  try
    format_table(
      "index_1(\"1\");index_3(\"2\");values(\"3\");", "lu_table_template(T){}",
    )
  catch {
    @liberty.LibertyError(code, _, _) => assert_eq(code, "TableShape")
  } noraise {
    _ => fail("axis gap accepted")
  }
}

///|
test "format reader verifies the supplied template identity" {
  let root = @liberty.parse_liberty(
    "library(x){cell_rise(T){values(\"1\");}lu_table_template(OTHER){}}",
  )
  try
    @liberty.read_table_data(
      root.groups("cell_rise")[0],
      template=root.groups("lu_table_template")[0],
    )
  catch {
    @liberty.LibertyError(code, _, _) => assert_eq(code, "TemplateMismatch")
  } noraise {
    _ => fail("wrong template accepted")
  }
}

///|
test "format reader permits local axis overrides" {
  let data = format_table(
    "index_1(\"2,4\");values(\"6,8\");", "lu_table_template(T){index_1(\"1,3\");}",
  )
  assert_eq(data.axes[0], [2.0, 4.0])
}

///|
test "format reader validates scalar independently from numerical lookup" {
  let root = @liberty.parse_liberty(
    "library(x){rise_constraint(scalar){values(\"-0.02\");}}",
  )
  let data = @liberty.read_table_data(root.groups("rise_constraint")[0])
  assert_eq(data.axes, [])
  assert_eq(data.rows, [[-0.02]])
}

///|
test "scalar template cannot silently acquire local axes" {
  let root = @liberty.parse_liberty(
    "library(x){cell_rise(scalar){index_1(\"1\");values(\"2\");}}",
  )
  for dimension in [0, 1] {
    try {
      if dimension == 0 {
        ignore(@liberty.read_table_data(root.groups("cell_rise")[0]))
      } else {
        ignore(@liberty.read_table(root.groups("cell_rise")[0]))
      }
    } catch {
      @liberty.LibertyError(code, _, _) => assert_eq(code, "TableShape")
    } noraise {
      _ => fail("scalar axis accepted")
    }
  }
}

///|
test "one dimensional values cannot be arbitrarily split into rows" {
  try
    format_table(
      "values(\"1\",\"2\");", "lu_table_template(T){index_1(\"1,2\");}",
    )
  catch {
    @liberty.LibertyError(code, _, _) => assert_eq(code, "TableShape")
  } noraise {
    _ => fail("split 1D rows accepted")
  }
}

///|
test "format validator bounds dimension products before multiplication" {
  let data : @liberty.TableData = {
    kind: "cell_rise",
    template_name: "T",
    axes: [Array::make(10000, 1.0), Array::make(10000, 1.0)],
    rows: [],
    position: { offset: 0, line: 1, column: 1, },
  }
  try @liberty.validate_table_data(data) catch {
    @liberty.LibertyError(code, _, _) =>
      assert_true(code == "NonIncreasingAxis" || code == "TableLimit")
  } noraise {
    _ => fail("large dimensions accepted")
  }
}

///|
test "public format data is revalidated after array mutation" {
  let data = format_table(
    "values(\"1,2\");", "lu_table_template(T){index_1(\"1,2\");}",
  )
  data.axes[0][1] = 1.0
  try @liberty.validate_table_data(data) catch {
    @liberty.LibertyError(code, _, _) => assert_eq(code, "NonIncreasingAxis")
  } noraise {
    _ => fail("mutated axis accepted")
  }
}

///|
test "named tables cannot silently become scalar when axes are missing or empty" {
  for
    template in [
      "lu_table_template(T){}", "lu_table_template(T){variable_1:input_net_transition;index_1();}",
    ] {
    let root = @liberty.parse_liberty(
      "library(x){" + template + "cell_rise(T){values(\"1\");}}",
    )
    for reader in [0, 1] {
      try {
        if reader == 0 {
          ignore(
            @liberty.read_table_data(
              root.groups("cell_rise")[0],
              template=root.groups("lu_table_template")[0],
            ),
          )
        } else {
          ignore(
            @liberty.read_table(
              root.groups("cell_rise")[0],
              template=root.groups("lu_table_template")[0],
            ),
          )
        }
      } catch {
        @liberty.LibertyError(code, _, _) => assert_eq(code, "TableShape")
      } noraise {
        _ => fail("missing axes interpreted as constant data")
      }
    }
  }
}

///|
test "declared dimensions must resolve axes before any lookup" {
  let root = @liberty.parse_liberty(
    "library(x){lu_table_template(T){variable_1:input_net_transition;variable_2:total_output_net_capacitance;index_1(\"1\");}cell_rise(T){values(\"2\");}}",
  )
  try
    @liberty.read_table(
      root.groups("cell_rise")[0],
      template=root.groups("lu_table_template")[0],
    )
  catch {
    @liberty.LibertyError(code, _, _) => assert_eq(code, "TableShape")
  } noraise {
    _ => fail("declared dimension dropped")
  }
}

///|
test "caller constructed format data respects scalar dimension identity" {
  let root = @liberty.parse_liberty(
    "library(x){cell_rise(scalar){values(\"1\");}}",
  )
  let scalar = @liberty.read_table_data(root.groups("cell_rise")[0])
  for
    invalid in [{ ..scalar, template_name: "T", }, { ..scalar, axes: [[1.0]], }] {
    try @liberty.validate_table_data(invalid) catch {
      @liberty.LibertyError(code, _, _) => assert_eq(code, "TableShape")
    } noraise {
      _ => fail("format dimension identity ignored")
    }
  }
}
