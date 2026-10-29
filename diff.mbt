///|
pub(all) enum ChangeKind {
  Added
  Removed
  Modified
} derive(Eq, Debug)

///|
pub(all) struct Change {
  kind : ChangeKind
  path : String
  before : String?
  after : String?
  preview_truncated : Bool
} derive(Eq, Debug)

///|
pub(all) struct Comparison {
  total_changes : Int32
  changes : Array[Change]
  truncated : Bool
} derive(Eq, Debug)

///|
fn path_escape(text : String) -> String {
  text.replace(old="~", new="~0").replace(old="/", new="~1")
}

///|
fn canonical_number_or_word(text : String) -> String {
  decimal_identity(text).unwrap_or(text)
}

///|
fn canonical_atom(atom : Atom) -> String {
  match atom {
    Word(text) => canonical_number_or_word(text)
    Text(text) => quoted_text(text)
  }
}

///|
fn canonical_value(name : String, atoms : Array[Atom]) -> String {
  let text = atoms_text(atoms)
  if name == "function" ||
    name == "when" ||
    name == "three_state" ||
    name == "next_state" ||
    name == "clocked_on" ||
    name == "enable" {
    try parse_logic(text) catch {
      _ => ()
    } noraise {
      expression => {
        let formatted = format_logic(expression) catch { _ => return text }
        return formatted
      }
    }
  }
  if name == "related_pin" {
    // Order can map corresponding members of buses/bundles. Never sort it away.
    return words(text).join(" ")
  }
  atoms.map(canonical_atom).join(" ")
}

///|
fn canonical_argument(name : String, atoms : Array[Atom]) -> String {
  if ["index_1", "index_2", "index_3", "values"].contains(name) {
    if atoms is [atom] {
      let values = []
      let mut numeric = true
      for part in atom_text(atom).split(",") {
        match decimal_identity(part.trim().to_owned()) {
          Some(value) => values.push(value)
          None => {
            numeric = false
            break
          }
        }
      }
      if numeric {
        return values.join(",")
      }
    }
  }
  atoms.map(canonical_atom).join(" ")
}

///|
fn group_identity(group : Group) -> String {
  if !group.name().is_empty() {
    return group.kind + ":" + group.name()
  }
  if group.kind == "timing" || group.kind == "internal_power" {
    let related = match group.text("related_pin") {
      Some(value) => canonical_value("related_pin", [Text(value)])
      None => ""
    }
    let condition = match group.text("when") {
      Some(value) => canonical_value("when", [Text(value)])
      None => ""
    }
    let timing_type = match group.text("timing_type") {
      Some(value) => value
      None => ""
    }
    return group.kind +
      ":" +
      [related, condition, timing_type].map(quoted_text).join(",")
  }
  group.kind +
  ":" +
  group.arguments.map(args => args.map(canonical_atom).join(" ")).join(",")
}

///|
fn put_entry(
  entries : Map[String, String],
  key : String,
  value : String,
  pos : Position,
) -> Unit raise LibertyError {
  if entries.length() >= 200000 {
    raise failure(
      "DiffLimit", "semantic comparison exceeds 200000 entries", pos,
    )
  }
  entries[key] = value
}

///|
fn flatten_group(
  group : Group,
  path : String,
  entries : Map[String, String],
  depth : Int32,
) -> Unit raise LibertyError {
  if depth > 128 {
    raise failure("DiffLimit", "comparison depth exceeds 128", group.position)
  }
  // An explicit group marker keeps empty added/removed cells visible.
  put_entry(entries, path + "/@group", group.kind, group.position)
  let occurrences : Map[String, Int32] = Map([])
  for item in group.items {
    let (key, value) = match item {
      Attribute(name, atoms, _) =>
        ("@" + name, Some(canonical_value(name, atoms)))
      Complex(name, arguments, _) =>
        (
          "call:" + name,
          Some(
            arguments
            .map(args => canonical_argument(name, args))
            .map(quoted_text)
            .join(","),
          ),
        )
      Section(child) => (group_identity(child), None)
    }
    let number = match occurrences.get(key) {
      Some(number) => number
      None => 0
    }
    occurrences[key] = number + 1
    let child_path = path + "/" + path_escape(key) + "#" + number.to_string()
    match item {
      Section(child) => flatten_group(child, child_path, entries, depth + 1)
      _ => put_entry(entries, child_path, value.unwrap(), group.position)
    }
  }
}

///|
fn semantic_entries(
  library : Library,
) -> Map[String, String] raise LibertyError {
  let entries : Map[String, String] = Map([])
  entries["library/@name"] = library.name
  flatten_group(library.source, "library", entries, 0)
  entries
}

///|
fn preview(value : String) -> String {
  if value.length() > 1024 {
    value[0:1024].to_owned() + "..."
  } else {
    value
  }
}

///|
pub fn compare_libraries(
  left : Library,
  right : Library,
  max_changes~ : Int32 = 10000,
) -> Comparison raise LibertyError {
  if max_changes < 1 || max_changes > 100000 {
    raise failure(
      "InvalidLimit",
      "max_changes must be in 1..100000",
      no_position(),
    )
  }
  for library in [left, right] {
    let errors = lint_library(library).filter(f => f.severity == Error)
    if !errors.is_empty() {
      raise failure(
        "InvalidLibrary",
        errors[0].code + ": " + errors[0].message,
        errors[0].position,
      )
    }
  }
  let a = semantic_entries(left)
  let b = semantic_entries(right)
  let all_keys : Map[String, Bool] = Map([])
  for key, _ in a {
    all_keys[key] = true
  }
  for key, _ in b {
    all_keys[key] = true
  }
  let keys = all_keys.keys().to_array()
  keys.sort_by(lexical_compare)
  let changes = []
  let mut total = 0
  for path in keys {
    let before = a.get(path)
    let after = b.get(path)
    if before == after {
      continue
    }
    total += 1
    if changes.length() >= max_changes {
      continue
    }
    let kind = match (before, after) {
      (None, Some(_)) => Added
      (Some(_), None) => Removed
      _ => Modified
    }
    changes.push({
      kind,
      path,
      before: before.map(preview),
      after: after.map(preview),
      preview_truncated: (before is Some(value) && value.length() > 1024) ||
      (after is Some(value) && value.length() > 1024),
    })
  }
  { total_changes: total, changes, truncated: total > changes.length(), }
}

///|
pub fn comparison_json(comparison : Comparison) -> Json {
  {
    "schema": "moonliberty.diff.v1",
    "has_changes": Json(comparison.total_changes != 0),
    "total_changes": Json(comparison.total_changes),
    "truncated": Json(comparison.truncated),
    "scope": "group/attribute semantics, numeric and Boolean syntax normalization; not electrical equivalence or STA signoff",
    "changes": Json(
      comparison.changes.map(change => {
        (
          {
            "kind": Json(
              match change.kind {
                Added => "added"
                Removed => "removed"
                Modified => "modified"
              },
            ),
            "path": Json(change.path),
            "before": nullable_text(change.before),
            "after": nullable_text(change.after),
            "preview_truncated": Json(change.preview_truncated),
          } : Json)
      }),
    ),
  }
}

///|
pub fn select_cells(
  library : Library,
  names : Array[String],
) -> Group raise LibertyError {
  if names.is_empty() {
    raise failure(
      "EmptySelection",
      "select at least one cell",
      library.source.position,
    )
  }
  for name in names {
    if library.cell(name) is None {
      raise failure(
        "MissingCell",
        "cannot extract unknown cell " + name,
        library.source.position,
      )
    }
  }
  {
    ..library.source,
    items: library.source.items.filter(item => {
      match item {
        Section(group) if group.kind == "cell" => names.contains(group.name())
        _ => true
      }
    }),
  }
}
