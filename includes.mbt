///|
/// Parse an include_file body as complete statements, never as a text splice.
pub fn parse_fragment(
  text : String,
  limits? : Limits = Limits::default(),
) -> Array[Node] raise LibertyError {
  let parser : Parser = {
    tokens: tokenize(text, limits~),
    limits,
    index: 0,
    nodes: 0,
  }
  let nodes = []
  while parser.peek().kind != End {
    nodes.push(parser.node(1))
  }
  nodes
}

///|
fn include_name(
  arguments : Array[Array[Atom]],
  pos : Position,
) -> String raise LibertyError {
  guard arguments is [[atom]] else {
    raise failure("IncludeArguments", "include_file needs one file name", pos)
  }
  let name = atom_text(atom)
  if name.is_empty() ||
    name == "." ||
    name == ".." ||
    name.contains("/") ||
    name.contains("\\") ||
    name.contains(":") ||
    name.contains_char('\u0000') {
    raise failure("IncludeName", "include_file requires a leaf file name", pos)
  }
  name
}

///|
priv struct IncludeExpander {
  sources : Map[String, String]
  limits : Limits
  mut input_chars : Int
  mut nodes : Int
}

///|
fn IncludeExpander::group(
  self : IncludeExpander,
  group : Group,
  depth : Int,
  from_include : Bool,
) -> Group raise LibertyError {
  if depth > self.limits.max_depth {
    raise failure(
      "DepthLimit",
      "expanded include nesting exceeds limit",
      group.position,
    )
  }
  let items = []
  for node in group.items {
    self.nodes += 1
    if self.nodes > self.limits.max_nodes {
      raise failure(
        "NodeLimit",
        "expanded include node budget exceeded",
        group.position,
      )
    }
    match node {
      Complex("include_file", arguments, pos) => {
        if from_include {
          raise failure(
            "NestedInclude", "included files cannot contain include_file", pos,
          )
        }
        let name = include_name(arguments, pos)
        let text = match self.sources.get(name) {
          Some(text) => text
          None =>
            raise failure(
              "MissingInclude",
              "no supplied source for " + name,
              pos,
            )
        }
        if text.length() > self.limits.max_input_chars - self.input_chars {
          raise failure(
            "InputLimit", "combined include input exceeds limit", pos,
          )
        }
        self.input_chars += text.length()
        let fragment = parse_fragment(text, limits=self.limits) catch {
          LibertyError(code, message, fragment_pos) =>
            raise LibertyError(code, name + ": " + message, fragment_pos)
        }
        if fragment.any(node => {
            match node {
              Section(g) => g.kind == "library"
              _ => false
            }
          }) {
          raise failure(
            "IncludeBoundary", "include body cannot introduce a library root", pos,
          )
        }
        let holder = { ..group, items: fragment, }
        let expanded = self.group(holder, depth, true)
        items.append(expanded.items)
      }
      Section(child) =>
        items.push(Section(self.group(child, depth + 1, from_include)))
      _ => items.push(node)
    }
  }
  { ..group, items, }
}

///|
/// Resolve caller-supplied include sources without reading the filesystem.
/// Nested includes and cross-group fragments are rejected (2017.06 include rules).
pub fn parse_liberty_sources(
  text : String,
  sources : Map[String, String],
  limits? : Limits = Limits::default(),
) -> Group raise LibertyError {
  let root = parse_liberty(text, limits~)
  let state : IncludeExpander = {
    sources,
    limits,
    input_chars: text.length(),
    nodes: 1,
  }
  let expanded = state.group(root, 1, false)
  // Combined, rather than per-file, token/node budgets also apply to the result.
  ignore(write_liberty(expanded, limits~))
  expanded
}
