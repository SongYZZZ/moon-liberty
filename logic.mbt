///|
pub(all) enum Logic {
  Signal(String)
  Constant(Bool)
  Not(Logic)
  And(Logic, Logic)
  Or(Logic, Logic)
  Xor(Logic, Logic)
} derive(Eq, Debug)

///|
pub(all) struct TruthRow {
  inputs : Array[(String, Bool)]
  output : Bool
} derive(Eq, Debug)

///|
priv struct LogicParser {
  text : String
  mut index : Int32
  mut nodes : Int32
}

///|
fn LogicParser::position(self : LogicParser) -> Position {
  { offset: self.index, line: 1, column: self.index + 1, }
}

///|
fn LogicParser::skip(self : LogicParser) -> Unit {
  while self.index < self.text.length() && whitespace(self.text[self.index]) {
    self.index += 1
  }
}

///|
fn LogicParser::peek(self : LogicParser) -> UInt16? {
  self.skip()
  if self.index < self.text.length() {
    Some(self.text[self.index])
  } else {
    None
  }
}

///|
fn LogicParser::bump(self : LogicParser) -> Unit raise LibertyError {
  self.nodes += 1
  if self.nodes > 10000 {
    raise failure(
      "LogicLimit",
      "Boolean expression exceeds node budget",
      self.position(),
    )
  }
}

///|
fn logic_identifier(code : UInt16) -> Bool {
  let n = code.to_int()
  (n >= 65 && n <= 90) ||
  (n >= 97 && n <= 122) ||
  (n >= 48 && n <= 57) ||
  [95, 91, 93, 46, 36, 92, 47].contains(n)
}

///|
fn LogicParser::unary(
  self : LogicParser,
  depth : Int32,
) -> Logic raise LibertyError {
  if depth > 128 {
    raise failure(
      "LogicDepth",
      "Boolean expression nesting exceeds 128",
      self.position(),
    )
  }
  self.bump()
  let mut value = match self.peek() {
    Some(33) | Some(126) => {
      self.index += 1
      Not(self.unary(depth + 1))
    }
    Some(40) => {
      self.index += 1
      let value = self.disjunction(depth + 1)
      if self.peek() != Some(41) {
        raise failure("BooleanParenthesis", "expected )", self.position())
      }
      self.index += 1
      value
    }
    Some(34) => {
      self.index += 1
      let start = self.index
      while self.index < self.text.length() && self.text[self.index] != 34 {
        if self.text[self.index] == 0 ||
          self.text[self.index] == 10 ||
          self.text[self.index] == 13 {
          raise failure(
            "BooleanIdentifier",
            "invalid quoted signal name",
            self.position(),
          )
        }
        self.index += 1
      }
      if self.index == self.text.length() || self.index == start {
        raise failure(
          "BooleanIdentifier",
          "quoted signal name must be nonempty and closed",
          self.position(),
        )
      }
      let name = self.text[start:self.index].to_owned()
      self.index += 1
      Signal(name)
    }
    Some(code) if logic_identifier(code) => {
      let start = self.index
      while self.index < self.text.length() &&
            logic_identifier(self.text[self.index]) {
        self.index += 1
      }
      let name = self.text[start:self.index].to_owned()
      if name == "0" {
        Constant(false)
      } else if name == "1" {
        Constant(true)
      } else {
        if name[0] >= 48 && name[0] <= 57 {
          raise failure(
            "BooleanLiteral",
            "only Boolean constants 0 and 1 are supported",
            self.position(),
          )
        }
        Signal(name)
      }
    }
    _ =>
      raise failure(
        "BooleanOperand",
        "expected signal, constant or (expression)",
        self.position(),
      )
  }
  while self.peek() == Some(39) {
    self.index += 1
    self.bump()
    value = Not(value)
  }
  value
}

///|
fn LogicParser::conjunction(
  self : LogicParser,
  depth : Int32,
) -> Logic raise LibertyError {
  let mut value = self.exclusive(depth)
  while true {
    let next = self.peek()
    let explicit = next == Some(38) || next == Some(42)
    let implicit = match next {
      Some(code) =>
        logic_identifier(code) ||
        code == 40 ||
        code == 33 ||
        code == 126 ||
        code == 34
      None => false
    }
    if !explicit && !implicit {
      break
    }
    if explicit {
      self.index += 1
    }
    self.bump()
    value = And(value, self.exclusive(depth))
  }
  value
}

///|
fn LogicParser::exclusive(
  self : LogicParser,
  depth : Int32,
) -> Logic raise LibertyError {
  let mut value = self.unary(depth)
  while self.peek() == Some(94) {
    self.index += 1
    self.bump()
    value = Xor(value, self.unary(depth))
  }
  value
}

///|
fn LogicParser::disjunction(
  self : LogicParser,
  depth : Int32,
) -> Logic raise LibertyError {
  let mut value = self.conjunction(depth)
  while self.peek() == Some(124) || self.peek() == Some(43) {
    self.index += 1
    self.bump()
    value = Or(value, self.conjunction(depth))
  }
  value
}

///|
pub fn parse_logic(text : String) -> Logic raise LibertyError {
  if text.length() > 65536 {
    raise failure(
      "LogicLimit",
      "Boolean source exceeds 65536 characters",
      no_position(),
    )
  }
  let parser : LogicParser = { text, index: 0, nodes: 0, }
  let value = parser.disjunction(0)
  if parser.peek() != None {
    raise failure(
      "BooleanTrailing",
      "unexpected trailing Boolean token",
      parser.position(),
    )
  }
  ignore(logic_signals(value))
  value
}

///|
pub fn logic_signals(expression : Logic) -> Array[String] raise LibertyError {
  let pending = [(expression, 0)]
  let names : Map[String, Bool] = Map([])
  let mut nodes = 0
  while pending.pop() is Some((value, depth)) {
    nodes += 1
    if nodes > 10000 || depth > 128 {
      raise failure(
        "LogicDepth",
        "Boolean AST exceeds structural limits",
        no_position(),
      )
    }
    match value {
      Signal(name) => names[name] = true
      Constant(_) => ()
      Not(inner) => pending.push((inner, depth + 1))
      And(a, b) | Or(a, b) | Xor(a, b) => {
        pending.push((a, depth + 1))
        pending.push((b, depth + 1))
      }
    }
  }
  let result = names.keys().to_array()
  result.sort_by(lexical_compare)
  result
}

///|
fn eval_logic(
  expression : Logic,
  values : Map[String, Bool],
) -> Bool raise LibertyError {
  match expression {
    Signal(name) =>
      match values.get(name) {
        Some(value) => value
        None =>
          raise failure(
            "MissingAssignment",
            "no value for signal " + name,
            no_position(),
          )
      }
    Constant(value) => value
    Not(inner) => !eval_logic(inner, values)
    And(a, b) => eval_logic(a, values) && eval_logic(b, values)
    Or(a, b) => eval_logic(a, values) || eval_logic(b, values)
    Xor(a, b) => eval_logic(a, values) != eval_logic(b, values)
  }
}

///|
pub fn evaluate_logic(
  expression : Logic,
  values : Map[String, Bool],
) -> Bool raise LibertyError {
  for name in logic_signals(expression) {
    if !values.contains(name) {
      raise failure(
        "MissingAssignment",
        "no value for signal " + name,
        no_position(),
      )
    }
  }
  eval_logic(expression, values)
}

///|
pub fn truth_table(
  expression : Logic,
  max_inputs~ : Int32 = 12,
) -> Array[TruthRow] raise LibertyError {
  let names = logic_signals(expression)
  if max_inputs < 0 || max_inputs > 16 || names.length() > max_inputs {
    raise failure(
      "TruthTableLimit",
      "truth table requires at most 16 explicitly budgeted inputs",
      no_position(),
    )
  }
  let rows = []
  let count = 1 << names.length()
  for mask = 0; mask < count; mask = mask + 1 {
    let values : Map[String, Bool] = Map([])
    let inputs = []
    for i = 0; i < names.length(); i = i + 1 {
      let value = (mask & (1 << (names.length() - i - 1))) != 0
      values[names[i]] = value
      inputs.push((names[i], value))
    }
    rows.push({ inputs, output: eval_logic(expression, values), })
  }
  rows
}

///|
fn format_logic_inner(expression : Logic) -> String {
  match expression {
    Signal(name) => {
      let mut bare = !name.is_empty() && !(name[0] >= 48 && name[0] <= 57)
      for i = 0; i < name.length(); i = i + 1 {
        if !logic_identifier(name[i]) {
          bare = false
        }
      }
      if bare {
        name
      } else {
        "\"" + name + "\""
      }
    }
    Constant(true) => "1"
    Constant(false) => "0"
    Not(inner) => "!(" + format_logic_inner(inner) + ")"
    And(a, b) =>
      "(" + format_logic_inner(a) + " & " + format_logic_inner(b) + ")"
    Or(a, b) =>
      "(" + format_logic_inner(a) + " | " + format_logic_inner(b) + ")"
    Xor(a, b) =>
      "(" + format_logic_inner(a) + " ^ " + format_logic_inner(b) + ")"
  }
}

///|
pub fn format_logic(expression : Logic) -> String raise LibertyError {
  ignore(logic_signals(expression))
  let text = format_logic_inner(expression)
  let reparsed = parse_logic(text) catch {
    _ =>
      raise failure(
        "InvalidLogicAst",
        "signal names cannot be represented without changing meaning",
        no_position(),
      )
  }
  if reparsed != expression {
    raise failure(
      "InvalidLogicAst",
      "formatter would change the Boolean expression",
      no_position(),
    )
  }
  text
}

///|
/// Explicit code-unit lexical order; core String comparison is length-first.
fn lexical_compare(a : String, b : String) -> Int32 {
  let length = if a.length() < b.length() { a.length() } else { b.length() }
  for i = 0; i < length; i = i + 1 {
    if a[i] != b[i] {
      return a[i].to_int() - b[i].to_int()
    }
  }
  a.length().compare(b.length())
}
