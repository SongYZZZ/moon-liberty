///|
fn compare_texts(
  a : String,
  b : String,
  max_changes? : Int = 10000,
) -> @liberty.Comparison raise {
  @liberty.compare_libraries(
    @liberty.load_library(a),
    @liberty.load_library(b),
    max_changes~,
  )
}

///|
test "whitespace comments and attribute order are not semantic changes" {
  let a = "library(x){ comment:\"hello\"; cell(A){area:2; pin(Y){direction:output;}}}"
  let b = "/* c */ library (x) { cell(A) {pin(Y){ direction : output; }area:2;}comment:\"hello\";}"
  assert_eq(compare_texts(a, b).total_changes, 0)
}

///|
test "numeric exponent spelling is normalized" {
  assert_eq(
    compare_texts(
      "library(x){cell(A){area:0.001;}}", "library(x){cell(A){area:1e-3;}}",
    ).total_changes,
    0,
  )
}

///|
test "audit detects neighboring integers beyond binary double precision" {
  assert_eq(
    compare_texts(
      "library(x){revision:9007199254740992;}", "library(x){revision:9007199254740993;}",
    ).total_changes,
    1,
  )
}

///|
test "audit detects decimal differences smaller than binary rounding" {
  assert_eq(
    compare_texts(
      "library(x){revision:0.10000000000000000;}", "library(x){revision:0.10000000000000001;}",
    ).total_changes,
    1,
  )
}

///|
test "audit normalizes exact signed decimal zeros and trailing zeros" {
  assert_eq(
    compare_texts(
      "library(x){a:+001.23000e+02;b:-0.000;}", "library(x){a:123;b:0e100;}",
    ).total_changes,
    0,
  )
}

///|
test "audit retains precise quoted numeric table rows" {
  let a = "library(x){vendor(V){values(\"9007199254740992\");}}"
  assert_eq(
    compare_texts(a, a.replace(old="9007199254740992", new="9007199254740993")).total_changes,
    1,
  )
}

///|
test "audit does not hide positional related pin changes" {
  assert_true(
    compare_texts(
      "library(x){vendor(V){related_pin:\"A B\";}}", "library(x){vendor(V){related_pin:\"B A\";}}",
    ).total_changes >
    0,
  )
}

///|
test "audit exponent normalization is bounded and never collapses huge exponents" {
  assert_eq(
    compare_texts(
      "library(x){a:1e999999999999;}", "library(x){a:1e999999999998;}",
    ).total_changes,
    1,
  )
}

///|
test "equivalent Boolean operator spellings are normalized" {
  let a = "library(x){cell(A){pin(A){direction:input;}pin(B){direction:input;}pin(Y){direction:output;function:\"A * B\";}}}"
  let b = a.replace(old="A * B", new="A & B")
  assert_eq(compare_texts(a, b).total_changes, 0)
}

///|
test "added empty cells are visible" {
  let result = compare_texts("library(x){}", "library(x){cell(A){}}")
  assert_true(
    result.changes.any(c => c.kind is Added && c.path.contains("cell:A")),
  )
}

///|
test "removed pins are visible" {
  let result = compare_texts(
    "library(x){cell(A){pin(Y){direction:output;}}}", "library(x){cell(A){}}",
  )
  assert_true(
    result.changes.any(c => c.kind is Removed && c.path.contains("pin:Y")),
  )
}

///|
test "function changes are reported" {
  let a = "library(x){cell(A){pin(A){direction:input;}pin(Y){direction:output;function:\"A\";}}}"
  let result = compare_texts(
    a,
    a.replace(old="function:\"A\"", new="function:\"!A\""),
  )
  assert_true(result.changes.any(c => c.path.contains("@function")))
}

///|
test "unknown vendor metadata changes are not silently ignored" {
  let a = "library(x){vendor(V){mystery:\"before\";}}"
  let b = "library(x){vendor(V){mystery:\"after\";}}"
  assert_eq(compare_texts(a, b).total_changes, 1)
}

///|
test "quoted numeric strings are not assumed to be numbers" {
  assert_eq(
    compare_texts("library(x){comment:\"1\";}", "library(x){comment:\"1.0\";}").total_changes,
    1,
  )
}

///|
test "lookup row numbers normalize without losing matrix shape" {
  let a = @liberty.write_liberty(small_library().source)
  let b = a.replace(old="\"1,2\"", new="\"1.0,2.0\"")
  assert_eq(compare_texts(a, b).total_changes, 0)
}

///|
test "unit declaration changes are explicit even if numeric table values stay equal" {
  let a = @liberty.write_liberty(small_library().source)
  assert_true(
    compare_texts(a, a.replace(old="1ns", new="1ps")).changes.any(c => {
      c.path.contains("time_unit")
    }),
  )
}

///|
test "diff cannot declare invalid libraries equivalent" {
  let a = @liberty.load_library("library(x){cell(A){area:-1;}}")
  try @liberty.compare_libraries(a, a) catch {
    @liberty.LibertyError(code, _, _) => assert_eq(code, "InvalidLibrary")
  } noraise {
    _ => fail("invalid library compared as equivalent")
  }
}

///|
test "bounded diff records total changes rather than hiding truncation" {
  let result = compare_texts(
    "library(x){cell(A){}}",
    "library(x){cell(A){area:2;pin(Y){direction:output;}}}",
    max_changes=1,
  )
  assert_true(result.total_changes > result.changes.length())
  assert_true(result.truncated)
}

///|
test "cell extraction preserves all global templates and metadata" {
  let library = @liberty.load_library(
    "library(x){time_unit:\"1ns\";lu_table_template(T){}cell(A){}cell(B){}}",
  )
  let selected = @liberty.select_cells(library, ["B"])
  assert_eq(selected.groups("cell").map(c => c.name()), ["B"])
  assert_eq(selected.groups("lu_table_template").length(), 1)
  assert_eq(selected.text("time_unit"), Some("1ns"))
}

///|
test "cell extraction refuses absent names and empty selection" {
  let library = small_library()
  for names in [[], ["NO"]] {
    try @liberty.select_cells(library, names) catch {
      @liberty.LibertyError(code, _, _) =>
        assert_true(code == "MissingCell" || code == "EmptySelection")
    } noraise {
      _ => fail("invalid cell extraction accepted")
    }
  }
}

///|
test "slash and tilde in group names cannot collide in comparison paths" {
  let result = compare_texts(
    "library(x){cell(\"A/B\"){}cell(\"A~1B\"){}}", "library(x){cell(\"A/B\"){}cell(\"A~1B\"){area:1;}}",
  )
  assert_eq(result.total_changes, 1)
  assert_true(result.changes[0].path.contains("A~01B"))
}

///|
test "library renames do not masquerade as removal of every cell" {
  let result = compare_texts("library(a){cell(A){}}", "library(b){cell(A){}}")
  assert_eq(result.total_changes, 1)
  assert_eq(result.changes[0].path, "library/@name")
}
