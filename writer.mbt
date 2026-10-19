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
  mut nodes : Int
}

///|
fn SyntaxWriter::indent(self : SyntaxWriter, depth : Int) -> Unit {
  for i = 0; i < depth; i = i + 1 {
    self.output.write_string("  ")
  }
}

///|
fn SyntaxWriter::group(
  self : SyntaxWriter,
  group : Group,
  depth : Int,
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
  limits? : Limits = Limits::default(),
) -> String raise LibertyError {
  let writer : SyntaxWriter = { output: StringBuilder(), limits, nodes: 0, }
  writer.group(group, 0)
  let output = writer.output.to_string()
  // Also validate caller-constructed ASTs and enforce output character budgets.
  ignore(parse_liberty(output, limits~))
  output
}
