///|
fn lint_codes(text : String) -> Array[String] raise {
  @liberty.lint_library(@liberty.load_library(text)).map(f => f.code)
}

///|
test "valid combinational model has no lint errors" {
  assert_false(
    @liberty.lint_library(small_library()).any(f => f.severity is Error),
  )
}

///|
test "duplicate cell declarations are errors" {
  assert_true(
    lint_codes("library(x){cell(A){}cell(A){}}").contains("DuplicateCell"),
  )
}

///|
test "duplicate pin declarations are errors" {
  assert_true(
    lint_codes("library(x){cell(A){pin(Y){}pin(Y){}}}").contains("DuplicatePin"),
  )
}

///|
test "missing cell names cannot pass semantic lint" {
  assert_true(lint_codes("library(x){cell(){}}").contains("MissingCellName"))
}

///|
test "missing pin names cannot pass semantic lint" {
  assert_true(
    lint_codes("library(x){cell(A){pin(){}}}").contains("MissingPinName"),
  )
}

///|
test "negative cell area is reported" {
  assert_true(
    lint_codes("library(x){cell(A){area:-1;}}").contains("NegativeArea"),
  )
}

///|
test "negative pin limits are reported" {
  assert_true(
    lint_codes("library(x){cell(A){pin(P){capacitance:-1;max_transition:-2;}}}").contains(
      "NegativePinLimit",
    ),
  )
}

///|
test "invalid pin direction is reported" {
  assert_true(
    lint_codes("library(x){cell(A){pin(P){direction:sideways;}}}").contains(
      "InvalidDirection",
    ),
  )
}

///|
test "absent pin direction is a warning rather than a fabricated value" {
  let findings = @liberty.lint_library(
    @liberty.load_library("library(x){cell(A){pin(P){}}}"),
  )
  assert_true(
    findings.any(f => f.code == "MissingDirection" && f.severity is Warning),
  )
}

///|
test "functions may not reference undeclared pins" {
  assert_true(
    lint_codes("library(x){cell(A){pin(Y){function:\"NO_SUCH_PIN\";}}}").contains(
      "UnknownSignal",
    ),
  )
}

///|
test "state signals declared by a flip flop are valid function references" {
  assert_false(
    lint_codes("library(x){cell(A){ff(IQ,IQN){}pin(Q){function:\"IQ\";}}}").contains(
      "UnknownSignal",
    ),
  )
}

///|
test "malformed Boolean functions produce a diagnostic" {
  assert_true(
    lint_codes("library(x){cell(A){pin(Y){function:\"A &\";}}}").contains(
      "BooleanOperand",
    ),
  )
}

///|
test "related pins must refer to declared pins" {
  assert_true(
    lint_codes("library(x){cell(A){pin(Y){timing(){related_pin:\"NO\";}}}}").contains(
      "UnknownRelatedPin",
    ),
  )
}

///|
test "arcs with lookup tables require a related pin" {
  assert_true(
    lint_codes(
      "library(x){cell(A){pin(Y){timing(){cell_rise(scalar){values(\"1\");}}}}}",
    ).contains("MissingRelatedPin"),
  )
}

///|
test "self pulse width constraints do not need related pin" {
  assert_false(
    lint_codes(
      "library(x){cell(A){pin(CLK){timing(){timing_type:min_pulse_width;rise_constraint(scalar){values(\"1\");}}}}}",
    ).contains("MissingRelatedPin"),
  )
}

///|
test "timing sense values are validated" {
  assert_true(
    lint_codes("library(x){cell(A){pin(Y){timing(){timing_sense:wrong;}}}}").contains(
      "InvalidTimingSense",
    ),
  )
}

///|
test "conditional expressions are checked against cell signals" {
  assert_true(
    lint_codes("library(x){cell(A){pin(Y){timing(){when:\"NO\";}}}}").contains(
      "UnknownSignal",
    ),
  )
}

///|
test "duplicate simple attributes are not silently accepted" {
  assert_true(
    lint_codes("library(x){cell(A){area:1;area:2;}}").contains(
      "DuplicateAttribute",
    ),
  )
}

///|
test "legitimately repeated non singleton complex attributes are retained" {
  assert_false(
    lint_codes(
      "library(x){wire_load(W){fanout_length(1,2);fanout_length(3,4);}}",
    ).contains("DuplicateAttribute"),
  )
}

///|
test "negative transition axes are rejected semantically" {
  assert_true(
    lint_codes(
      "library(x){lu_table_template(T){index_1(\"-1,1\");}cell(A){pin(A){direction:input;}pin(Y){timing(){related_pin:\"A\";cell_rise(T){values(\"1,2\");}}}}}",
    ).contains("NegativeAxis"),
  )
}

///|
test "diagnostics retain file positions and structural paths" {
  let findings = @liberty.lint_library(
    @liberty.load_library("library(x){\ncell(A){\narea:-1;\n}}"),
  )
  let issue = findings.iter().find_first(f => f.code == "NegativeArea").unwrap()
  assert_eq(issue.position.line, 3)
  assert_eq(issue.path, "x/cell:A/area")
}

///|
test "statetable internal names resolve in functions and timing conditions" {
  let source = "library(x){time_unit:\"1ns\";capacitive_load_unit(1,pf);cell(C){" +
    "pin(A){direction:input;}statetable(\"A\",\"IQ IQN\"){table:\"L:- -:L H,H:- -:H L\";}" +
    "pin(Y){direction:output;function:\"IQ ^ IQN\";timing(){related_pin:\"A\";when:\"IQ\";}}}}"
  let library = @liberty.load_library(source)
  assert_eq(
    @liberty.compatibility_report(library.source).findings.filter(f => {
      f.severity is Error
    }),
    [],
  )
  assert_eq(@liberty.lint_library(library).filter(f => f.severity is Error), [])
}

///|
test "statetable state names remain cell scoped and are not related pins" {
  let source = "library(x){cell(C){pin(A){direction:input;}statetable(\"A\",\"IQ\"){table:\"L:-:L,H:-:H\";}" +
    "pin(Y){direction:output;function:\"IQ | MISSING\";timing(){related_pin:\"IQ\";}}}" +
    "cell(D){pin(Y){direction:output;function:\"IQ\";}}}"
  let findings = @liberty.lint_library(@liberty.load_library(source))
  let unknown = findings.filter(f => f.code == "UnknownSignal")
  assert_eq(unknown.length(), 2)
  assert_true(
    unknown.any(f => {
      f.path == "x/cell:C/pin:Y/function" && f.message.contains("MISSING")
    }),
  )
  assert_true(
    unknown.any(f => {
      f.path == "x/cell:D/pin:Y/function" && f.message.contains("IQ")
    }),
  )
  assert_true(findings.any(f => f.code == "UnknownRelatedPin"))
}
