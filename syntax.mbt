///|
pub(all) enum Atom {
  Word(String)
  Text(String)
} derive(Eq, Debug)

///|
pub(all) enum Node {
  Attribute(String, Array[Atom], Position)
  Complex(String, Array[Array[Atom]], Position)
  Section(Group)
} derive(Eq, Debug)

///|
pub(all) struct Group {
  kind : String
  arguments : Array[Array[Atom]]
  items : Array[Node]
  position : Position
} derive(Eq, Debug)

///|
pub fn atom_text(atom : Atom) -> String {
  match atom {
    Word(value) | Text(value) => value
  }
}

///|
pub fn atoms_text(atoms : Array[Atom]) -> String {
  atoms.map(atom_text).join(" ")
}

///|
pub fn Group::name(self : Group) -> String {
  if self.arguments.length() == 1 && self.arguments[0].length() == 1 {
    atom_text(self.arguments[0][0])
  } else {
    ""
  }
}

///|
pub fn Group::groups(self : Group, kind : String) -> Array[Group] {
  self.items.filter_map(node => {
    match node {
      Section(group) if group.kind == kind => Some(group)
      _ => None
    }
  })
}

///|
pub fn Group::attribute(self : Group, name : String) -> Array[Atom]? {
  for item in self.items {
    if item is Attribute(key, value, _) && key == name {
      return Some(value.copy())
    }
  }
  None
}

///|
pub fn Group::text(self : Group, name : String) -> String? {
  self.attribute(name).map(atoms_text)
}

///|
pub fn Group::complex(self : Group, name : String) -> Array[Array[Atom]]? {
  for item in self.items {
    if item is Complex(key, values, _) && key == name {
      return Some(values.map(v => v.copy()))
    }
  }
  None
}

///|
priv struct Parser {
  tokens : Array[Token]
  limits : Limits
  mut index : Int
  mut nodes : Int
}

///|
fn Parser::peek(self : Parser) -> Token {
  self.tokens[self.index]
}

///|
fn Parser::is_symbol(self : Parser, text : String) -> Bool {
  let token = self.peek()
  token.kind == Symbol && token.text == text
}

///|
fn Parser::take(self : Parser) -> Token {
  let token = self.peek()
  self.index += 1
  token
}

///|
fn Parser::expect(self : Parser, text : String) -> Unit raise LibertyError {
  if !self.is_symbol(text) {
    raise failure("ExpectedSymbol", "expected " + text, self.peek().position)
  }
  ignore(self.take())
}

///|
fn Parser::atom(self : Parser) -> Atom raise LibertyError {
  let token = self.take()
  match token.kind {
    Quoted => Text(token.text)
    Bare | Symbol => Word(token.text)
    End => raise failure("UnexpectedEnd", "expected a value", token.position)
  }
}

///|
fn Parser::arguments(self : Parser) -> Array[Array[Atom]] raise LibertyError {
  self.expect("(")
  if self.is_symbol(")") {
    ignore(self.take())
    return []
  }
  let values = []
  let mut current = []
  let mut nesting = 0
  while true {
    let token = self.peek()
    if token.kind == End {
      raise failure("UnclosedArguments", "expected )", token.position)
    }
    if self.is_symbol(")") && nesting == 0 {
      if current.is_empty() {
        raise failure(
          "EmptyArgument",
          "empty or trailing argument",
          token.position,
        )
      }
      values.push(current)
      ignore(self.take())
      return values
    }
    if self.is_symbol(",") && nesting == 0 {
      if current.is_empty() {
        raise failure("EmptyArgument", "empty argument", token.position)
      }
      values.push(current)
      current = []
      ignore(self.take())
    } else {
      if self.is_symbol("(") {
        nesting += 1
        if nesting > self.limits.max_depth {
          raise failure(
            "DepthLimit",
            "argument nesting exceeds limit",
            token.position,
          )
        }
      } else if self.is_symbol(")") {
        nesting -= 1
      } else if self.is_symbol("{") ||
        self.is_symbol("}") ||
        self.is_symbol(";") {
        raise failure(
          "InvalidArgument",
          "unexpected structural token in argument",
          token.position,
        )
      }
      current.push(self.atom())
    }
  } nobreak {
    raise failure("UnclosedArguments", "expected )", self.peek().position)
  }
}

///|
fn Parser::node(self : Parser, depth : Int) -> Node raise LibertyError {
  if depth > self.limits.max_depth {
    raise failure(
      "DepthLimit",
      "group nesting exceeds limit",
      self.peek().position,
    )
  }
  self.nodes += 1
  if self.nodes > self.limits.max_nodes {
    raise failure(
      "NodeLimit",
      "AST node count exceeds limit",
      self.peek().position,
    )
  }
  let name = self.take()
  if name.kind != Bare {
    raise failure(
      "ExpectedName",
      "statement name must be unquoted",
      name.position,
    )
  }
  if self.is_symbol(":") {
    ignore(self.take())
    let atoms = []
    let mut nesting = 0
    while !self.is_symbol(";") {
      let token = self.peek()
      if token.kind == End || self.is_symbol("}") || self.is_symbol("{") {
        raise failure(
          "MissingSemicolon",
          "attribute must end with ;",
          token.position,
        )
      }
      if self.is_symbol("(") {
        nesting += 1
      }
      if self.is_symbol(")") {
        nesting -= 1
        if nesting < 0 {
          raise failure(
            "UnbalancedValue",
            "extra ) in attribute",
            token.position,
          )
        }
      }
      if nesting > self.limits.max_depth {
        raise failure(
          "DepthLimit",
          "value nesting exceeds limit",
          token.position,
        )
      }
      atoms.push(self.atom())
    }
    if atoms.is_empty() {
      raise failure("MissingValue", "attribute requires a value", name.position)
    }
    if nesting != 0 {
      raise failure("UnbalancedValue", "unclosed ( in attribute", name.position)
    }
    ignore(self.take())
    return Attribute(name.text, atoms, name.position)
  }
  if !self.is_symbol("(") {
    raise failure(
      "ExpectedStatement",
      "expected : or ( after statement name",
      self.peek().position,
    )
  }
  let arguments = self.arguments()
  if !self.is_symbol("{") {
    self.expect(";")
    return Complex(name.text, arguments, name.position)
  }
  ignore(self.take())
  let items = []
  while !self.is_symbol("}") {
    if self.peek().kind == End {
      raise failure(
        "UnclosedGroup",
        "expected } for " + name.text,
        name.position,
      )
    }
    items.push(self.node(depth + 1))
  }
  ignore(self.take())
  // A semicolon after a closed group is tolerated by common Liberty writers.
  if self.is_symbol(";") {
    ignore(self.take())
  }
  Section({ kind: name.text, arguments, items, position: name.position, })
}

///|
pub fn parse_liberty(
  text : String,
  limits? : Limits = Limits::default(),
) -> Group raise LibertyError {
  let parser : Parser = {
    tokens: tokenize(text, limits~),
    limits,
    index: 0,
    nodes: 0,
  }
  if parser.peek().kind == End {
    raise failure("MissingLibrary", "expected one library group", no_position())
  }
  let root = match parser.node(1) {
    Section(group) if group.kind == "library" && !group.name().is_empty() =>
      group
    _ =>
      raise failure(
        "InvalidRoot",
        "expected one named library(...) group",
        no_position(),
      )
  }
  if parser.peek().kind != End {
    raise failure(
      "MultipleRoots",
      "only one library is accepted per document",
      parser.peek().position,
    )
  }
  root
}
