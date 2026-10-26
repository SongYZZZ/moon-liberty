///|
fn table(
  x : Array[Double],
  y : Array[Double],
  values : Array[Double],
) -> @liberty.Table {
  {
    kind: "cell_rise",
    template_name: "test",
    variable_1: Some("input_net_transition"),
    variable_2: Some("total_output_net_capacitance"),
    index_1: x,
    index_2: y,
    values,
    position: { offset: 0, line: 1, column: 1, },
  }
}

///|
fn table_error(
  t : @liberty.Table,
  x? : Double = 0.0,
  y? : Double,
  policy? : @liberty.RangePolicy = Reject,
) -> String raise {
  try @liberty.lookup_table(t, x, y?, policy~) catch {
    @liberty.LibertyError(code, _, _) => code
  } noraise {
    _ => fail("expected lookup rejection")
  }
}

///|
test "scalar lookup returns its constant" {
  near(@liberty.lookup_table(table([], [], [3.0]), 0.0).value, 3.0)
}

///|
test "one dimensional interpolation respects actual axis spacing" {
  near(
    @liberty.lookup_table(table([1.0, 5.0], [], [2.0, 10.0]), 3.0).value,
    6.0,
  )
}

///|
test "bilinear interpolation uses index one as row and index two as column" {
  let t = table([0.0, 10.0], [0.0, 100.0], [0.0, 300.0, 20.0, 320.0])
  near(@liberty.lookup_table(t, 5.0, y=25.0).value, 85.0)
}

///|
test "exact last node is not mistaken for outside the table" {
  let result = @liberty.lookup_table(
    table([0.0, 1.0], [0.0, 1.0], [0.0, 1.0, 2.0, 3.0]),
    1.0,
    y=1.0,
  )
  near(result.value, 3.0)
  assert_false(result.extrapolated)
}

///|
test "exact interior knots select correct intervals" {
  let t = table([0.0, 2.0, 3.0], [], [1.0, 5.0, 10.0])
  near(@liberty.lookup_table(t, 2.0).value, 5.0)
}

///|
test "singleton axes work at their defined coordinate" {
  near(@liberty.lookup_table(table([2.0], [], [7.0]), 2.0).value, 7.0)
}

///|
test "singleton second axis works as a degenerate dimension" {
  near(
    @liberty.lookup_table(table([0.0, 2.0], [3.0], [1.0, 5.0]), 1.0, y=3.0).value,
    3.0,
  )
}

///|
test "default out of range policy refuses lower coordinates" {
  assert_eq(table_error(table([1.0, 2.0], [], [1.0, 3.0]), x=0.0), "OutOfRange")
}

///|
test "default out of range policy refuses upper coordinates" {
  assert_eq(table_error(table([1.0, 2.0], [], [1.0, 3.0]), x=3.0), "OutOfRange")
}

///|
test "clamp policy reports clamping" {
  let result = @liberty.lookup_table(
    table([1.0, 2.0], [], [1.0, 3.0]),
    3.0,
    policy=Clamp,
  )
  near(result.value, 3.0)
  assert_true(result.clamped)
  assert_false(result.extrapolated)
}

///|
test "linear extrapolation is opt in and clearly reported" {
  let result = @liberty.lookup_table(
    table([1.0, 2.0], [], [1.0, 3.0]),
    3.0,
    policy=Extrapolate,
  )
  near(result.value, 5.0)
  assert_true(result.extrapolated)
  assert_false(result.clamped)
}

///|
test "extrapolation of a singleton cannot invent a slope" {
  assert_eq(
    table_error(table([1.0], [], [3.0]), x=2.0, policy=Extrapolate),
    "InsufficientAxis",
  )
}

///|
test "second coordinate is mandatory for a two dimensional table" {
  assert_eq(
    table_error(table([0.0, 1.0], [0.0, 1.0], [0.0, 1.0, 2.0, 3.0])),
    "MissingCoordinate",
  )
}

///|
test "extra coordinates on one dimensional tables are rejected" {
  assert_eq(
    table_error(table([0.0, 1.0], [], [0.0, 1.0]), y=0.0),
    "UnexpectedCoordinate",
  )
}

///|
test "empty values cannot form a scalar table" {
  assert_eq(table_error(table([], [], [])), "TableShape")
}

///|
test "matrix dimensions must match axis lengths" {
  assert_eq(
    table_error(table([0.0, 1.0], [0.0, 1.0], [0.0, 1.0])),
    "TableShape",
  )
}

///|
test "duplicate axis knots cannot cause division by zero" {
  assert_eq(
    table_error(table([1.0, 1.0], [], [1.0, 2.0]), x=1.0),
    "NonIncreasingAxis",
  )
}

///|
test "descending axes are rejected rather than reordered with incorrect values" {
  assert_eq(
    table_error(table([2.0, 1.0], [], [1.0, 2.0]), x=1.0),
    "NonIncreasingAxis",
  )
}

///|
test "index two without index one is invalid" {
  assert_eq(table_error(table([], [0.0], [1.0])), "TableShape")
}

///|
test "negative finite table values are retained" {
  near(
    @liberty.lookup_table(table([0.0, 1.0], [], [-2.0, -1.0]), 0.5).value,
    -1.5,
  )
}

///|
test "lookup revalidates public table arrays after caller modification" {
  let t = table([0.0, 1.0], [], [1.0, 2.0])
  t.index_1[1] = 0.0
  assert_eq(table_error(t), "NonIncreasingAxis")
}

///|
test "table axes can inherit from a named template" {
  let root = @liberty.parse_liberty(
    "library(x){lu_table_template(T){variable_1:input_net_transition;index_1(\"1,2\");}cell_rise(T){values(\"3,5\");}}",
  )
  let t = @liberty.read_table(
    root.groups("cell_rise")[0],
    template=root.groups("lu_table_template")[0],
  )
  near(@liberty.lookup_table(t, 1.5).value, 4.0)
}

///|
test "local table axes override template defaults" {
  let root = @liberty.parse_liberty(
    "library(x){lu_table_template(T){index_1(\"1,2\");}cell_rise(T){index_1(\"10,20\");values(\"3,5\");}}",
  )
  let t = @liberty.read_table(
    root.groups("cell_rise")[0],
    template=root.groups("lu_table_template")[0],
  )
  assert_eq(t.index_1, [10.0, 20.0])
}

///|
test "unknown templates are not silently treated as scalar" {
  let root = @liberty.parse_liberty(
    "library(x){cell_rise(missing){values(\"1\");}}",
  )
  try @liberty.read_table(root.groups("cell_rise")[0]) catch {
    @liberty.LibertyError(code, _, _) => assert_eq(code, "MissingTemplate")
  } noraise {
    _ => fail("missing template accepted")
  }
}

///|
test "scalar template does not need a declaration" {
  let root = @liberty.parse_liberty(
    "library(x){cell_rise(scalar){values(\"0.25\");}}",
  )
  near(
    @liberty.lookup_table(@liberty.read_table(root.groups("cell_rise")[0]), 0.0).value,
    0.25,
  )
}

///|
test "two dimensional rows cannot be transposed silently" {
  let root = @liberty.parse_liberty(
    "library(x){cell_rise(T){index_1(\"1,2\");index_2(\"1,2,3\");values(\"1,2\",\"3,4\",\"5,6\");}lu_table_template(T){}}",
  )
  try
    @liberty.read_table(
      root.groups("cell_rise")[0],
      template=root.groups("lu_table_template")[0],
    )
  catch {
    @liberty.LibertyError(code, _, _) => assert_eq(code, "TableShape")
  } noraise {
    _ => fail("transposed matrix accepted")
  }
}

///|
test "three dimensional tables are explicitly unsupported" {
  let root = @liberty.parse_liberty(
    "library(x){cell_rise(T){index_1(\"1\");index_2(\"1\");index_3(\"1,2\");values(\"1,2\");}lu_table_template(T){}}",
  )
  try
    @liberty.read_table(
      root.groups("cell_rise")[0],
      template=root.groups("lu_table_template")[0],
    )
  catch {
    @liberty.LibertyError(code, _, _) => assert_eq(code, "UnsupportedDimension")
  } noraise {
    _ => fail("3D table accepted")
  }
}

///|
test "affine surfaces are recovered over deterministic interior coordinates" {
  let t = table([0.0, 2.0, 5.0], [0.0, 10.0, 30.0], [
    7.0, 37.0, 97.0, 11.0, 41.0, 101.0, 17.0, 47.0, 107.0,
  ])
  for i = 0; i <= 20; i = i + 1 {
    let x = i.to_double() / 4.0
    let y = i.to_double() * 1.5
    near(@liberty.lookup_table(t, x, y~).value, 7.0 + 2.0 * x + 3.0 * y)
  }
}
