///|
pub(all) struct Position {
  offset : Int32
  line : Int32
  column : Int32
} derive(Eq, Debug)

///|
pub(all) suberror LibertyError {
  LibertyError(String, String, Position)
} derive(Debug)

///|
pub fn LibertyError::render(self : LibertyError) -> String {
  let LibertyError(code, message, pos) = self
  "\{code} at \{pos.line}:\{pos.column}: \{message}"
}

///|
pub(all) struct Limits {
  max_input_chars : Int32
  max_tokens : Int32
  max_token_chars : Int32
  max_depth : Int32
  max_nodes : Int32
} derive(Eq, Debug)

///|
pub fn Limits::default() -> Limits {
  {
    max_input_chars: 16777216,
    max_tokens: 2000000,
    max_token_chars: 1048576,
    max_depth: 128,
    max_nodes: 1000000,
  }
}

///|
fn failure(
  code : String,
  message : String,
  position : Position,
) -> LibertyError {
  LibertyError(code, message, position)
}

///|
fn no_position() -> Position {
  { offset: 0, line: 1, column: 1, }
}

///|
pub(all) enum Severity {
  Warning
  Error
} derive(Eq, Debug)

///|
pub(all) struct Finding {
  code : String
  severity : Severity
  path : String
  message : String
  position : Position
} derive(Eq, Debug)
