///|
fn quoted_text(text : String) -> String {
  let out = StringBuilder()
  out.write_string("\"")
  for i = 0; i < text.length(); i = i + 1 {
    let code = text[i]
    if code == 34 || code == 92 {
      out.write_string("\\")
    }
    out.write_stringview(text[i:i + 1])
  }
  out.write_string("\"")
  out.to_string()
}

///|
fn render_atoms(atoms : Array[Atom]) -> String {
  atoms
  .map(atom => {
    match atom {
      Text(text) => quoted_text(text)
      Word(text) => text
    }
  })
  .join(" ")
}

///|
priv struct SyntaxWriter {
  output : StringBuilder
  limits : Limits
  mut nodes : Int32
}

///|
priv struct WriterBudget {
  limits : Limits
  mut chars : Int32
  mut nodes : Int32
}

///|
fn WriterBudget::add(
  self : WriterBudget,
  count : Int32,
  pos : Position,
) -> Unit raise LibertyError {
  if count > self.limits.max_input_chars - self.chars {
    raise failure("InputLimit", "rendered syntax exceeds character budget", pos)
  }
  self.chars += count
}

///|
fn WriterBudget::atoms(
  self : WriterBudget,
  atoms : Array[Atom],
  pos : Position,
) -> Unit raise LibertyError {
  for i = 0; i < atoms.length(); i = i + 1 {
    if i > 0 {
      self.add(1, pos)
    }
    let text = atom_text(atoms[i])
    self.add(text.length(), pos)
    if atoms[i] is Text(_) {
      self.add(2, pos)
      for j = 0; j < text.length(); j = j + 1 {
        if text[j] == 34 || text[j] == 92 {
          self.add(1, pos)
        }
      }
    }
  }
}

///|
fn WriterBudget::arguments(
  self : WriterBudget,
  args : Array[Array[Atom]],
  pos : Position,
) -> Unit raise LibertyError {
  for i = 0; i < args.length(); i = i + 1 {
    if i > 0 {
      self.add(2, pos)
    }
    self.atoms(args[i], pos)
  }
}

///|
fn WriterBudget::group(
  self : WriterBudget,
  group : Group,
  depth : Int32,
) -> Unit raise LibertyError {
  if depth >= self.limits.max_depth {
    raise failure("DepthLimit", "writer nesting exceeds limit", group.position)
  }
  self.nodes += 1
  if self.nodes > self.limits.max_nodes {
    raise failure("NodeLimit", "writer node budget exceeded", group.position)
  }
  self.add(depth * 2, group.position)
  self.add(group.kind.length(), group.position)
  self.add(6, group.position)
  self.arguments(group.arguments, group.position)
  for item in group.items {
    match item {
      Section(child) => self.group(child, depth + 1)
      Attribute(name, _, pos) | Complex(name, _, pos) => {
        self.nodes += 1
        if self.nodes > self.limits.max_nodes {
          raise failure("NodeLimit", "writer node budget exceeded", pos)
        }
        self.add((depth + 1) * 2, pos)
        self.add(name.length(), pos)
        self.add(5, pos)
        match item {
          Attribute(_, values, _) => self.atoms(values, pos)
          Complex(_, args, _) => self.arguments(args, pos)
          _ => ()
        }
      }
    }
  }
  self.add(depth * 2, group.position)
  self.add(2, group.position)
}

///|
fn SyntaxWriter::indent(self : SyntaxWriter, depth : Int32) -> Unit {
  for i = 0; i < depth; i = i + 1 {
    self.output.write_string("  ")
  }
}

///|
fn SyntaxWriter::group(
  self : SyntaxWriter,
  group : Group,
  depth : Int32,
) -> Unit raise LibertyError {
  if depth >= self.limits.max_depth {
    raise failure("DepthLimit", "writer nesting exceeds limit", group.position)
  }
  self.nodes += 1
  if self.nodes > self.limits.max_nodes {
    raise failure("NodeLimit", "writer node budget exceeded", group.position)
  }
  self.indent(depth)
  self.output.write_string(
    group.kind + " (" + group.arguments.map(render_atoms).join(", ") + ") {\n",
  )
  for item in group.items {
    match item {
      Section(child) => self.group(child, depth + 1)
      Attribute(name, atoms, pos) => {
        self.nodes += 1
        if self.nodes > self.limits.max_nodes {
          raise failure("NodeLimit", "writer node budget exceeded", pos)
        }
        self.indent(depth + 1)
        self.output.write_string(name + " : " + render_atoms(atoms) + ";\n")
      }
      Complex(name, arguments, pos) => {
        self.nodes += 1
        if self.nodes > self.limits.max_nodes {
          raise failure("NodeLimit", "writer node budget exceeded", pos)
        }
        self.indent(depth + 1)
        self.output.write_string(
          name + " (" + arguments.map(render_atoms).join(", ") + ");\n",
        )
      }
    }
  }
  self.indent(depth)
  self.output.write_string("}\n")
}

///|
pub fn write_liberty(
  group : Group,
  limits~ : Limits = Limits::default(),
) -> String raise LibertyError {
  // Validate budgets before allocating the rendered text, including escaping
  // and indentation. Caller-constructed ASTs need not originate in the lexer.
  ignore(tokenize("", limits~))
  let budget : WriterBudget = { limits, chars: 0, nodes: 0, }
  budget.group(group, 0)
  let writer : SyntaxWriter = { output: StringBuilder(), limits, nodes: 0, }
  writer.group(group, 0)
  let output = writer.output.to_string()
  // Also validate caller-constructed ASTs and enforce output character budgets.
  let reparsed = parse_liberty(output, limits~)
  if !same_syntax(group, reparsed) {
    raise failure(
      "InvalidAst",
      "writer would change caller-constructed syntax",
      group.position,
    )
  }
  output
}

///|
fn same_syntax(before : Group, after : Group) -> Bool {
  if before.kind != after.kind ||
    before.arguments != after.arguments ||
    before.items.length() != after.items.length() {
    return false
  }
  for i in 0..<before.items.length() {
    let equal = match (before.items[i], after.items[i]) {
      (Attribute(a, x, _), Attribute(b, y, _)) => a == b && x == y
      (Complex(a, x, _), Complex(b, y, _)) => a == b && x == y
      (Section(a), Section(b)) => same_syntax(a, b)
      _ => false
    }
    if !equal {
      return false
    }
  }
  true
}
