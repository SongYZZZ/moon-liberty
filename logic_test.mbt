///|
fn logic_outputs(text : String) -> Array[Bool] raise {
  @liberty.truth_table(@liberty.parse_logic(text)).map(row => row.output)
}

///|
fn logic_error(text : String) -> String raise {
  try @liberty.parse_logic(text) catch {
    @liberty.LibertyError(code, _, _) => code
  } noraise {
    _ => fail("expected Boolean rejection")
  }
}

///|
test "constant Boolean functions produce one row" {
  assert_eq(logic_outputs("0"), [false])
  assert_eq(logic_outputs("1"), [true])
}

///|
test "one signal has deterministic false then true ordering" {
  assert_eq(logic_outputs("A"), [false, true])
}

///|
test "prefix inversion is supported" {
  assert_eq(logic_outputs("!A"), [true, false])
  assert_eq(logic_outputs("~A"), [true, false])
}

///|
test "postfix inversion is supported" {
  assert_eq(logic_outputs("A'"), [true, false])
}

///|
test "double postfix inversion restores a signal" {
  assert_eq(logic_outputs("A''"), [false, true])
}

///|
test "Liberty star and ampersand are AND operators" {
  assert_eq(logic_outputs("A * B"), [false, false, false, true])
  assert_eq(logic_outputs("A & B"), [false, false, false, true])
}

///|
test "Liberty plus and pipe are OR operators" {
  assert_eq(logic_outputs("A + B"), [false, true, true, true])
  assert_eq(logic_outputs("A | B"), [false, true, true, true])
}

///|
test "exclusive or is distinguished from inclusive or" {
  assert_eq(logic_outputs("A ^ B"), [false, true, true, false])
}

///|
test "adjacent operands imply conjunction" {
  assert_eq(logic_outputs("A B"), logic_outputs("A & B"))
  assert_eq(logic_outputs("A(B)"), logic_outputs("A & B"))
}

///|
test "adjacent inverted operand implies conjunction" {
  assert_eq(logic_outputs("A!B"), [false, false, true, false])
}

///|
test "AND binds before OR" {
  assert_eq(logic_outputs("A | B & C"), logic_outputs("A | (B & C)"))
}

///|
test "AND binds before XOR" {
  assert_eq(logic_outputs("A ^ B & C"), logic_outputs("A ^ (B & C)"))
}

///|
test "XOR binds before OR" {
  assert_eq(logic_outputs("A | B ^ C"), logic_outputs("A | (B ^ C)"))
}

///|
test "parentheses can override precedence" {
  assert_false(logic_outputs("(A | B) & C") == logic_outputs("A | B & C"))
}

///|
test "postfix complement can apply to a whole parenthesized expression" {
  assert_eq(logic_outputs("(A & B)'"), [true, true, true, false])
}

///|
test "signal names preserve case and bus selectors" {
  assert_eq(@liberty.logic_signals(@liberty.parse_logic("A[0] | a")), [
    "A[0]", "a",
  ])
}

///|
test "undefined assignments are rejected even on short circuit branches" {
  try
    @liberty.evaluate_logic(@liberty.parse_logic("A & B"), Map([("A", false)]))
  catch {
    @liberty.LibertyError(code, _, _) => assert_eq(code, "MissingAssignment")
  } noraise {
    _ => fail("missing assignment accepted")
  }
}

///|
test "an empty Boolean expression is rejected" {
  assert_eq(logic_error(""), "BooleanOperand")
}

///|
test "unsupported operators are not ignored" {
  assert_eq(logic_error("A ? B : C"), "BooleanTrailing")
}

///|
test "missing operands and parentheses are rejected" {
  assert_eq(logic_error("A &"), "BooleanOperand")
  assert_eq(logic_error("(A"), "BooleanParenthesis")
}

///|
test "unsupported numeric constants are rejected" {
  assert_eq(logic_error("2"), "BooleanLiteral")
}

///|
test "Boolean formatting is semantically round trippable" {
  let expression = @liberty.parse_logic("!(A B) + C'")
  assert_eq(
    logic_outputs(@liberty.format_logic(expression)),
    @liberty.truth_table(expression).map(row => row.output),
  )
}

///|
test "truth tables have explicit exponential size budgets" {
  try @liberty.truth_table(@liberty.parse_logic("A | B"), max_inputs=1) catch {
    @liberty.LibertyError(code, _, _) => assert_eq(code, "TruthTableLimit")
  } noraise {
    _ => fail("truth table budget ignored")
  }
}

///|
test "Boolean nesting is bounded" {
  let out = StringBuilder()
  for i = 0; i < 200; i = i + 1 {
    out.write_string("!")
  }
  out.write_string("A")
  assert_eq(logic_error(out.to_string()), "LogicDepth")
}
