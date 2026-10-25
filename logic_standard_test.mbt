///|
test "Liberty inversion XOR AND OR precedence follows 2017.06" {
  assert_eq(
    @liberty.parse_logic("A & B ^ C"),
    @liberty.And(
      @liberty.Signal("A"),
      @liberty.Xor(@liberty.Signal("B"), @liberty.Signal("C")),
    ),
  )
  assert_eq(
    @liberty.parse_logic("A ^ B * C + D"),
    @liberty.Or(
      @liberty.And(
        @liberty.Xor(@liberty.Signal("A"), @liberty.Signal("B")),
        @liberty.Signal("C"),
      ),
      @liberty.Signal("D"),
    ),
  )
  assert_eq(
    @liberty.parse_logic("!A ^ B' C"),
    @liberty.And(
      @liberty.Xor(
        @liberty.Not(@liberty.Signal("A")),
        @liberty.Not(@liberty.Signal("B")),
      ),
      @liberty.Signal("C"),
    ),
  )
}

///|
test "quoted numeric signal names differ from Boolean constants" {
  assert_eq(@liberty.logic_signals(@liberty.parse_logic("\"1A\" + \"0\"")), [
    "0", "1A",
  ])
  assert_eq(@liberty.parse_logic("0"), @liberty.Constant(false))
}

///|
test "quoted signal names participate in implicit conjunction" {
  assert_eq(
    @liberty.parse_logic("A \"1B\""),
    @liberty.And(@liberty.Signal("A"), @liberty.Signal("1B")),
  )
}

///|
test "unclosed empty or newline quoted logic names fail" {
  for text in ["\"\"", "\"abc", "\"a\nb\""] {
    try @liberty.parse_logic(text) catch {
      @liberty.LibertyError(code, _, _) => assert_eq(code, "BooleanIdentifier")
    } noraise {
      _ => fail("invalid quoted signal accepted")
    }
  }
}

///|
test "Liberty nested quoted identifiers resolve actual pin names" {
  let library = @liberty.load_library(
    "library(x){cell(C){pin(1A){direction:input;}pin(Y){direction:output;function:\"\\\"1A\\\"\";}}}",
  )
  assert_eq(
    @liberty.lint_library(library).filter(f => f.severity == @liberty.Error),
    [],
  )
}
