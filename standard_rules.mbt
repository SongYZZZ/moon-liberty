///|
/// Identifiers of implemented rule families, not an exhaustive manual inventory.
pub fn standard_rule_ids() -> Array[String] {
  [
    "group-parent", "group-arguments", "attribute-form", "attribute-type", "attribute-duplicate",
    "template-axis", "template-reference", "table-shape", "table-order", "transition-nonnegative",
    "bus-type", "bus-range", "bus-members", "state-arguments", "state-references",
    "statetable-nodes", "statetable-rows", "statetable-tokens",
  ]
}

///|
fn std_parents(kind : String) -> Array[String]? {
  match kind {
    "cell"
    | "type"
    | "lu_table_template"
    | "power_lut_template"
    | "operating_conditions"
    | "wire_load" => Some(["library"])
    "pin" =>
      Some(["cell", "test_cell", "scaled_cell", "model", "bus", "bundle"])
    "bus"
    | "bundle"
    | "pg_pin"
    | "ff"
    | "ff_bank"
    | "latch"
    | "latch_bank"
    | "statetable" => Some(["cell", "test_cell", "scaled_cell", "model"])
    "timing" | "internal_power" => Some(["pin", "bus", "bundle"])
    "leakage_power" => Some(["cell"])
    "cell_rise"
    | "cell_fall"
    | "rise_transition"
    | "fall_transition"
    | "rise_constraint"
    | "fall_constraint" => Some(["timing"])
    "rise_power" | "fall_power" => Some(["internal_power"])
    _ => None
  }
}

///|
fn std_attr_type(kind : String, name : String) -> String? {
  if kind == "type" {
    return match name {
      "base_type" => Some("array")
      "data_type" => Some("bit")
      "bit_from" | "bit_to" | "bit_width" => Some("integer")
      "downto" => Some("boolean")
      _ => None
    }
  }
  if kind == "cell" {
    if name == "area" {
      return Some("float")
    }
    if [
        "dont_use", "dont_touch", "is_macro_cell", "is_pad", "is_filler_cell", "is_decap_cell",
        "is_tap_cell", "is_clock_gating_cell", "always_on",
      ].contains(name) {
      return Some("boolean")
    }
  }
  if ["pin", "bus", "bundle"].contains(kind) {
    if name == "direction" {
      return Some("direction")
    }
    if [
        "capacitance", "rise_capacitance", "fall_capacitance", "max_capacitance",
        "min_capacitance", "max_transition", "min_transition", "max_fanout", "fanout_load",
      ].contains(name) {
      return Some("float")
    }
    if [
        "clock", "clock_gate_clock_pin", "clock_gate_enable_pin", "clock_gate_test_pin",
        "clock_gate_out_pin", "is_pad", "is_pass_gate", "is_unbuffered", "always_on",
      ].contains(name) {
      return Some("boolean")
    }
    if [
        "function", "three_state", "bus_type", "related_power_pin", "related_ground_pin",
      ].contains(name) {
      return Some("atom")
    }
  }
  if kind == "timing" {
    if name == "timing_sense" {
      return Some("sense")
    }
    if name == "default_timing" {
      return Some("boolean")
    }
    if [
        "related_pin", "related_bus_pins", "related_output_pin", "when", "timing_type",
      ].contains(name) {
      return Some("atom")
    }
  }
  if ["lu_table_template", "power_lut_template"].contains(kind) &&
    ["variable_1", "variable_2", "variable_3"].contains(name) {
    return Some("atom")
  }
  if ["ff", "ff_bank", "latch", "latch_bank"].contains(kind) &&
    [
      "clocked_on", "clocked_on_also", "next_state", "clear", "preset", "data_in",
      "enable", "enable_also",
    ].contains(name) {
    return Some("expression")
  }
  if kind == "statetable" && name == "table" {
    return Some("string")
  }
  if kind == "library" &&
    [
      "time_unit", "voltage_unit", "current_unit", "leakage_power_unit", "pulling_resistance_unit",
      "bus_naming_style",
    ].contains(name) {
    return Some("string")
  }
  None
}

///|
fn std_value_valid(value_type : String, atoms : Array[Atom]) -> Bool {
  if value_type == "expression" {
    return !atoms.is_empty() && !atoms_text(atoms).is_empty()
  }
  guard atoms is [atom] else { return false }
  let text = atom_text(atom)
  match value_type {
    "array" => text == "array"
    "bit" => text == "bit"
    "direction" => ["input", "output", "inout", "internal"].contains(text)
    "sense" => ["positive_unate", "negative_unate", "non_unate"].contains(text)
    "atom" => !text.is_empty()
    _ => attribute_value_valid(value_type, atoms)
  }
}

///|
fn std_issue(
  findings : Array[Finding],
  code : String,
  group : Group,
  path : String,
  message : String,
) -> Unit {
  add_finding(findings, code, path, message, group.position)
}

///|
fn std_group_rules(
  group : Group,
  parent : String,
  path : String,
  findings : Array[Finding],
) -> Unit {
  if std_parents(group.kind) is Some(parents) {
    if !parents.contains(parent) {
      std_issue(
        findings, "StandardGroupParent", group, path, "group is not permitted in this parent by the implemented rule",
      )
    }
    if [
        "cell", "type", "lu_table_template", "power_lut_template", "bus", "bundle",
        "pg_pin", "operating_conditions", "wire_load",
      ].contains(group.kind) &&
      group.name().is_empty() {
      std_issue(
        findings, "StandardGroupArguments", group, path, "group needs one nonempty name",
      )
    }
    if group.kind == "pin" &&
      (
        group.arguments.is_empty() ||
        group.arguments.any(a => a.length() != 1 || atom_text(a[0]).is_empty())
      ) {
      std_issue(
        findings, "StandardGroupArguments", group, path, "pin needs one or more nonempty pin names",
      )
    }
    duplicate_properties(group, path, findings)
  }
  for item in group.items {
    match item {
      Attribute(name, atoms, pos) =>
        if std_attr_type(group.kind, name) is Some(value_type) &&
          !std_value_valid(value_type, atoms) {
          add_finding(
            findings,
            "StandardAttributeType",
            path + "/" + name,
            "expected " + value_type + " value",
            pos,
          )
        }
      Complex(name, _, pos) =>
        if std_attr_type(group.kind, name) != None {
          add_finding(
            findings,
            "StandardAttributeForm",
            path + "/" + name,
            "standard simple attribute must use name : value;",
            pos,
          )
        }
      _ => ()
    }
  }
}

///|
fn std_template(
  group : Group,
  path : String,
  findings : Array[Finding],
) -> Unit {
  let mut gap = false
  let seen : Map[String, Bool] = Map([])
  for axis in ["1", "2", "3"] {
    let variable = group.text("variable_" + axis)
    let numbers = vector(group, "index_" + axis) catch {
      error => {
        findings.push(finding(error, path + "/index_" + axis))
        continue
      }
    }
    match (variable, numbers) {
      (None, None) => gap = true
      (Some(name), Some(values)) => {
        if gap || values.is_empty() || seen.contains(name) {
          std_issue(
            findings, "StandardTemplateAxis", group, path, "axes must be contiguous, nonempty and use distinct variables",
          )
        }
        seen[name] = true
        for i = 0; i < values.length(); i = i + 1 {
          if values[i] < 0.0 || (i > 0 && values[i] <= values[i - 1]) {
            std_issue(
              findings,
              "StandardTemplateAxis",
              group,
              path + "/index_" + axis,
              "lookup breakpoints must be nonnegative and strictly increasing",
            )
            break
          }
        }
      }
      _ =>
        std_issue(
          findings, "StandardTemplateAxis", group, path, "each variable requires its corresponding index",
        )
    }
  }
  if group.text("variable_1") == None {
    std_issue(
      findings, "StandardTemplateAxis", group, path, "lookup template needs variable_1 and index_1",
    )
  }
}

///|
fn std_table(
  group : Group,
  templates : Map[String, Group],
  path : String,
  findings : Array[Finding],
) -> Unit {
  let template_kind = if group.kind == "rise_power" ||
    group.kind == "fall_power" {
    "power_lut_template"
  } else {
    "lu_table_template"
  }
  let template = templates.get(template_kind + "/" + group.name())
  if group.name() != "scalar" && template == None {
    std_issue(
      findings,
      "StandardTemplateReference",
      group,
      path,
      "missing " + template_kind + " named " + group.name(),
    )
    return
  }
  let data = read_table_data(group, template?) catch {
    error => {
      findings.push(finding(error, path))
      return
    }
  }
  let mut seen_values = false
  for item in group.items {
    if item is Complex(name, _, pos) {
      if name == "values" {
        seen_values = true
      }
      if ["index_1", "index_2", "index_3"].contains(name) && seen_values {
        add_finding(
          findings,
          "StandardTableOrder",
          path + "/" + name,
          "local indexes must precede values",
          pos,
        )
      }
    }
  }
  if data.axes.any(axis => axis.any(value => value < 0.0)) {
    std_issue(
      findings, "StandardTableAxis", group, path, "NLDM/power breakpoints must be nonnegative",
    )
  }
  if ["rise_transition", "fall_transition"].contains(group.kind) &&
    data.rows.any(row => row.any(value => value < 0.0)) {
    std_issue(
      findings, "NegativeTransition", group, path, "transition table values must be nonnegative",
    )
  }
}

///|
fn std_integer(
  group : Group,
  name : String,
  path : String,
  findings : Array[Finding],
) -> Int? {
  guard group.attribute(name) is Some(atoms) &&
    attribute_value_valid("integer", atoms) else {
    return None
  }
  let value = finite_number(atoms_text(atoms)) catch {
    error => {
      findings.push(finding(error, path + "/" + name))
      return None
    }
  }
  if value < -1000000.0 || value > 1000000.0 {
    std_issue(
      findings,
      "RuleResourceLimit",
      group,
      path + "/" + name,
      "implemented bus/state integer budget is +/-1000000; format validity is undetermined",
    )
    return None
  }
  Some(value.to_int())
}

///|
fn std_bus_type(
  group : Group,
  path : String,
  findings : Array[Finding],
) -> Unit {
  let width = std_integer(group, "bit_width", path, findings)
  let from = std_integer(group, "bit_from", path, findings)
  let to = std_integer(group, "bit_to", path, findings)
  if width is Some(n) && n < 1 {
    std_issue(
      findings, "StandardBusRange", group, path, "bit_width must be positive",
    )
  }
  if (from is Some(n) && n < 0) || (to is Some(n) && n < 0) {
    std_issue(
      findings, "StandardBusRange", group, path, "bus member numbers must be nonnegative",
    )
  }
  if width is Some(width) && from is Some(from) && to is Some(to) {
    let distance = if from > to { from - to } else { to - from }
    if width != distance + 1 {
      std_issue(
        findings, "StandardBusRange", group, path, "bit_width differs from explicit endpoint distance",
      )
    }
  }
  if from is Some(from) &&
    to is Some(to) &&
    group.text("downto") is Some(order) &&
    from != to {
    if (order == "true" && from < to) || (order == "false" && from > to) {
      std_issue(
        findings, "StandardBusRange", group, path, "downto contradicts explicit endpoints",
      )
    }
  }
}

///|
fn std_bus(
  group : Group,
  types : Map[String, Group],
  path : String,
  findings : Array[Finding],
) -> Unit {
  let name = group.text("bus_type").unwrap_or("")
  if !types.contains(name) {
    std_issue(
      findings, "StandardBusType", group, path, "bus_type must reference a declared library type",
    )
    return
  }
  let first = group.items.get(0)
  if !(first is Some(Attribute("bus_type", _, _))) {
    std_issue(
      findings, "StandardBusType", group, path, "bus_type must be the first statement in bus",
    )
  }
  let definition = types[name]
  let from = std_integer(definition, "bit_from", path, findings)
  let to = std_integer(definition, "bit_to", path, findings)
  for pin in group.groups("pin") {
    if group.text("direction") is Some(direction) &&
      pin.text("direction") is Some(overridden) &&
      direction != overridden {
      std_issue(
        findings, "StandardBusMember", pin, path, "bus members must share direction",
      )
    }
    for argument in pin.arguments {
      if argument is [atom] &&
        atom_text(atom).split_once("[") is Some((base, tail)) &&
        tail.has_suffix("]") {
        if base != group.name() {
          std_issue(
            findings, "StandardBusMember", pin, path, "member prefix differs from bus name",
          )
        }
        let range_text = tail[0:tail.length() - 1].to_owned()
        let ends = range_text.split(":").map(v => v.to_owned()).to_array()
        if ends.length() > 2 || ends.is_empty() {
          std_issue(
            findings, "StandardBusMember", pin, path, "member needs one number or a range",
          )
          continue
        }
        for end in ends {
          if !attribute_value_valid("integer", [Word(end)]) {
            std_issue(
              findings, "StandardBusMember", pin, path, "member number must be an integer",
            )
            continue
          }
          let number = finite_number(end) catch {
            _ => {
              std_issue(
                findings, "RuleResourceLimit", pin, path, "member number exceeds numeric budget",
              )
              continue
            }
          }
          if from is Some(from) && to is Some(to) {
            let low = if from < to { from } else { to }
            let high = if from > to { from } else { to }
            if number < low.to_double() || number > high.to_double() {
              std_issue(
                findings, "StandardBusMember", pin, path, "member is outside type endpoints",
              )
            }
          }
        }
      }
    }
  }
}

///|
fn std_cell_names(cell : Group) -> Map[String, Bool] {
  let names : Map[String, Bool] = Map([])
  for item in cell.items {
    if item is Section(group) {
      if ["pin", "bus", "bundle", "pg_pin"].contains(group.kind) {
        for argument in group.arguments {
          if argument is [atom] {
            names[atom_text(atom)] = true
          }
        }
      }
      if ["ff", "latch", "ff_bank", "latch_bank"].contains(group.kind) {
        for i = 0; i < 2 && i < group.arguments.length(); i = i + 1 {
          if group.arguments[i] is [atom] {
            names[atom_text(atom)] = true
          }
        }
      }
      if group.kind == "statetable" &&
        declaration_argument(group.arguments, 1) is Some(states) {
        for name in words(states) {
          names[name] = true
        }
      }
    }
  }
  names
}

///|
fn std_state(
  group : Group,
  cell : Group?,
  path : String,
  findings : Array[Finding],
) -> Unit {
  let bank = group.kind == "ff_bank" || group.kind == "latch_bank"
  let arity = if bank { 3 } else { 2 }
  if group.arguments.length() != arity ||
    declaration_argument(group.arguments, 0).unwrap_or("").is_empty() ||
    declaration_argument(group.arguments, 1).unwrap_or("").is_empty() ||
    declaration_argument(group.arguments, 0) ==
    declaration_argument(group.arguments, 1) {
    std_issue(
      findings, "StandardStateArguments", group, path, "state group needs two distinct internal names and a width for bank groups",
    )
  }
  if bank {
    let width = declaration_argument(group.arguments, 2).unwrap_or("")
    let positive = if attribute_value_valid("integer", [Word(width)]) {
      (finite_number(width) catch { _ => 0.0 }) > 0.0
    } else {
      false
    }
    if !positive {
      std_issue(
        findings, "StandardStateArguments", group, path, "state bank width must be a positive integer",
      )
    }
  }
  if cell is Some(cell) {
    let names = std_cell_names(cell)
    for
      key in [
        "clocked_on", "clocked_on_also", "next_state", "clear", "preset", "data_in",
        "enable", "enable_also",
      ] {
      if group.text(key) is Some(expression) {
        check_logic(
          expression,
          names,
          path + "/" + key,
          simple_position(group, key),
          findings,
        )
      }
    }
  }
}

///|
fn std_statetable(
  group : Group,
  cell : Group?,
  path : String,
  findings : Array[Finding],
) -> Unit {
  if group.arguments.length() != 2 ||
    !(group.arguments.get(0) is Some([Text(_)])) ||
    !(group.arguments.get(1) is Some([Text(_)])) {
    std_issue(
      findings, "StandardStateTableNodes", group, path, "statetable needs two quoted node lists",
    )
    return
  }
  let inputs = words(declaration_argument(group.arguments, 0).unwrap_or(""))
  let states = words(declaration_argument(group.arguments, 1).unwrap_or(""))
  let names : Map[String, Bool] = Map([])
  for name in inputs + states {
    if names.contains(name) {
      std_issue(
        findings, "StandardStateTableNodes", group, path, "statetable node names must be unique",
      )
    }
    names[name] = true
  }
  if states.is_empty() {
    std_issue(
      findings, "StandardStateTableNodes", group, path, "statetable requires internal nodes",
    )
  }
  if cell is Some(cell) {
    let declared = std_cell_names(cell)
    for name in inputs {
      if !declared.contains(name) {
        std_issue(
          findings,
          "UnknownSignal",
          group,
          path,
          "statetable input is undeclared: " + name,
        )
      }
    }
    if cell.groups("statetable").length() > 1 {
      std_issue(
        findings, "StandardStateTableNodes", group, path, "cell may contain only one statetable",
      )
    }
  }
  let table = group.text("table").unwrap_or("")
  if table.is_empty() {
    std_issue(
      findings, "StandardStateTableRows", group, path, "statetable requires nonempty table string",
    )
    return
  }
  for row in table.split(",") {
    let parts = row.split(":").map(v => words(v.to_owned())).to_array()
    if parts.length() != 3 ||
      parts[0].length() != inputs.length() ||
      parts[1].length() != states.length() ||
      parts[2].length() != states.length() {
      std_issue(
        findings, "StandardStateTableRows", group, path, "row must match input, current-state and next-state node counts",
      )
      continue
    }
    for i = 0; i < 3; i = i + 1 {
      let allowed = if i == 0 {
        ["L", "H", "-", "L/H", "H/L", "R", "F", "~R", "~F"]
      } else if i == 1 {
        ["L", "H", "-", "L/H", "H/L"]
      } else {
        ["L", "H", "-", "L/H", "H/L", "X", "N"]
      }
      if parts[i].any(token => !allowed.contains(token)) {
        std_issue(
          findings, "StandardStateTableToken", group, path, "token is not valid in this statetable column",
        )
      }
    }
  }
}

///|
fn std_walk(
  group : Group,
  parent : String,
  cell : Group?,
  templates : Map[String, Group],
  types : Map[String, Group],
  path : String,
  findings : Array[Finding],
) -> Unit {
  std_group_rules(group, parent, path, findings)
  let scope = if ["cell", "test_cell", "scaled_cell", "model"].contains(
      group.kind,
    ) {
    Some(group)
  } else {
    cell
  }
  match group.kind {
    "lu_table_template" | "power_lut_template" =>
      std_template(group, path, findings)
    "type" => std_bus_type(group, path, findings)
    "bus" => std_bus(group, types, path, findings)
    "ff" | "ff_bank" | "latch" | "latch_bank" =>
      std_state(group, scope, path, findings)
    "statetable" => std_statetable(group, scope, path, findings)
    _ =>
      if timing_table_kind(group.kind) ||
        ["rise_power", "fall_power"].contains(group.kind) {
        std_table(group, templates, path, findings)
      }
  }
  for item in group.items {
    if item is Section(child) {
      std_walk(
        child,
        group.kind,
        scope,
        templates,
        types,
        path + "/" + child.kind + "(" + child.name() + ")",
        findings,
      )
    }
  }
}

///|
/// Apply documented, implemented 2017.06 rules. This is not complete conformance.
pub fn standard_findings(root : Group) -> Array[Finding] {
  let findings = []
  let templates : Map[String, Group] = Map([])
  let types : Map[String, Group] = Map([])
  for item in root.items {
    if item is Section(group) {
      if ["lu_table_template", "power_lut_template"].contains(group.kind) {
        let key = group.kind + "/" + group.name()
        if templates.contains(key) {
          std_issue(
            findings,
            "DuplicateTemplate",
            group,
            "/library/" + key,
            "template name is duplicated in its namespace",
          )
        } else {
          templates[key] = group
        }
      }
      if group.kind == "type" {
        if types.contains(group.name()) {
          std_issue(
            findings, "DuplicateType", group, "/library/type", "bus type name is duplicated",
          )
        } else {
          types[group.name()] = group
        }
      }
    }
  }
  std_walk(
    root,
    "",
    None,
    templates,
    types,
    "/library(" + root.name() + ")",
    findings,
  )
  findings
}
