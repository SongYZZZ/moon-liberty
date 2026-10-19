///|
fn lex_error(
  text : String,
  limits? : @liberty.Limits = @liberty.Limits::default(),
) -> String raise {
  try @liberty.tokenize(text, limits~) catch {
    @liberty.LibertyError(code, _, _) => code
  } noraise {
    _ => fail("expected lexer rejection")
  }
}

///|
test "empty input produces only the end token" {
  let tokens = @liberty.tokenize("")
  assert_eq(tokens.length(), 1)
  assert_true(tokens[0].kind is End)
}

///|
test "group punctuation cannot be consumed as a name" {
  let tokens = @liberty.tokenize("cell(NAND2){area:1.2;}")
  assert_eq(tokens.map(t => t.text), [
    "cell", "(", "NAND2", ")", "{", "area", ":", "1.2", ";", "}", "",
  ])
}

///|
test "quoted delimiters and comments remain literal" {
  let tokens = @liberty.tokenize("\"a/*b*/;,(c)\"")
  assert_eq(tokens[0].text, "a/*b*/;,(c)")
  assert_true(tokens[0].kind is Quoted)
}

///|
test "comments are removed without merging adjacent tokens" {
  let tokens = @liberty.tokenize("a/*hidden*/b // tail\n c")
  assert_eq(tokens.map(t => t.text), ["a", "b", "c", ""])
}

///|
test "token positions track lines and columns" {
  let tokens = @liberty.tokenize(" \n  cell")
  assert_eq(tokens[0].position.line, 2)
  assert_eq(tokens[0].position.column, 3)
  assert_eq(tokens[0].position.offset, 4)
}

///|
test "unterminated comment reports its opening position" {
  assert_eq(lex_error("x /*bad"), "UnterminatedComment")
}

///|
test "unterminated quoted value is refused" {
  assert_eq(lex_error("\"bad"), "UnterminatedString")
}

///|
test "unescaped line breaks inside quotes are refused" {
  assert_eq(lex_error("\"a\nb\""), "UnescapedNewline")
}

///|
test "quoted escape and escaped quote are decoded" {
  assert_eq(@liberty.tokenize("\"a\\\"b\\\\c\"")[0].text, "a\"b\\c")
}

///|
test "unknown vendor escapes are preserved" {
  assert_eq(@liberty.tokenize("\"a\\tb\"")[0].text, "a\\tb")
}

///|
test "backslash continuation is removed outside strings" {
  assert_eq(@liberty.tokenize("a \\\n b").map(t => t.text), ["a", "b", ""])
}

///|
test "backslash continuation is removed inside strings" {
  assert_eq(@liberty.tokenize("\"a\\\nb\"")[0].text, "ab")
}

///|
test "CRLF continuation preserves physical line tracking" {
  let tokens = @liberty.tokenize("a \\\r\nb")
  assert_eq(tokens[1].position.line, 2)
}

///|
test "bare NUL is rejected" {
  assert_eq(lex_error("a\u0000b"), "InvalidCharacter")
}

///|
test "input budget is enforced" {
  assert_eq(
    lex_error("abcd", limits={
      ..@liberty.Limits::default(),
      max_input_chars: 3,
    }),
    "InputLimit",
  )
}

///|
test "token length budget is enforced" {
  assert_eq(
    lex_error("abcd", limits={
      ..@liberty.Limits::default(),
      max_token_chars: 3,
    }),
    "TokenLimit",
  )
}

///|
test "token count budget is enforced" {
  assert_eq(
    lex_error("a b", limits={ ..@liberty.Limits::default(), max_tokens: 1, }),
    "TokenLimit",
  )
}

///|
test "invalid limits cannot disable bounds" {
  assert_eq(
    lex_error("a", limits={ ..@liberty.Limits::default(), max_depth: 0, }),
    "InvalidLimit",
  )
}

///|
test "scientific signed and bus tokens survive lexing" {
  assert_eq(@liberty.tokenize("-1.5e-3 A[0] 1ns").map(t => t.text), [
    "-1.5e-3", "A[0]", "1ns", "",
  ])
}
