///|
fn add_finding(
  findings : Array[Finding],
  code : String,
  path : String,
  message : String,
  position : Position,
  severity? : Severity = Error,
) -> Unit {
  findings.push({ code, severity, path, message, position, })
}

///|
fn duplicate_properties(
  group : Group,
  path : String,
  findings : Array[Finding],
) -> Unit {
  let seen : Map[String, Bool] = Map([])
  for item in group.items {
    let property = match item {
      Attribute(name, _, pos) => Some((name, pos))
      Complex(name, _, pos) if [
          "index_1", "index_2", "index_3", "values", "capacitive_load_unit",
        ].contains(name) => Some((name, pos))
      _ => None
    }
    if property is Some((name, pos)) {
      if seen.contains(name) {
        add_finding(
          findings,
          "DuplicateAttribute",
          path + "/" + name,
          "property occurs more than once",
          pos,
        )
      }
      seen[name] = true
    }
  }
}

///|
fn check_logic(
  text : String,
  names : Map[String, Bool],
  path : String,
  position : Position,
  findings : Array[Finding],
) -> Unit {
  let expression = parse_logic(text) catch {
    error => {
      let LibertyError(code, message, _) = error
      add_finding(findings, code, path, message, position)
      return
    }
  }
  let signals = logic_signals(expression) catch {
    error => {
      findings.push(finding(error, path))
      return
    }
  }
  for name in signals {
    if !names.contains(name) {
      add_finding(
        findings,
        "UnknownSignal",
        path,
        "Boolean expression references undeclared signal " + name,
        position,
      )
    }
  }
}

///|
pub fn lint_library(library : Library) -> Array[Finding] {
  let findings = library.findings.copy()
  if library.units is Some(units) {
    validate_units(units) catch {
      error => findings.push(finding(error, library.name + "/units"))
    }
  }
  duplicate_properties(library.source, library.name, findings)
  let cell_names : Map[String, Bool] = Map([])
  if library.cells.is_empty() {
    add_finding(
      findings,
      "NoCells",
      library.name,
      "library contains no directly declared standard cells",
      library.source.position,
      severity=Warning,
    )
  }
  for template in library.templates {
    duplicate_properties(
      template,
      library.name + "/template:" + template.name(),
      findings,
    )
    if template.name().is_empty() {
      add_finding(
        findings,
        "MissingTemplateName",
        library.name,
        "template must have one name",
        template.position,
      )
    }
  }
  for cell in library.cells {
    let path = library.name + "/cell:" + cell.name
    duplicate_properties(cell.source, path, findings)
    if cell.name.is_empty() {
      add_finding(
        findings,
        "MissingCellName",
        path,
        "cell requires one name",
        cell.source.position,
      )
    }
    if cell_names.contains(cell.name) {
      add_finding(
        findings,
        "DuplicateCell",
        path,
        "cell name occurs more than once",
        cell.source.position,
      )
    }
    cell_names[cell.name] = true
    if cell.area is Some(area) && (area < 0.0 || area.is_nan() || area.is_inf()) {
      add_finding(
        findings,
        if area.is_nan() || area.is_inf() {
          "NonFiniteNumber"
        } else {
          "NegativeArea"
        },
        path + "/area",
        "cell area must be finite and nonnegative",
        simple_position(cell.source, "area"),
      )
    }
    let pin_names : Map[String, Bool] = Map([])
    let logic_names : Map[String, Bool] = Map([])
    for pin in cell.pins {
      if pin.name.is_empty() {
        add_finding(
          findings,
          "MissingPinName",
          path,
          "pin requires one name",
          pin.source.position,
        )
      }
      if pin_names.contains(pin.name) {
        add_finding(
          findings,
          "DuplicatePin",
          path + "/pin:" + pin.name,
          "pin name occurs more than once",
          pin.source.position,
        )
      }
      pin_names[pin.name] = true
      logic_names[pin.name] = true
    }
    for state in cell.source.groups("ff") + cell.source.groups("latch") {
      for argument in state.arguments {
        if argument.length() == 1 {
          logic_names[atom_text(argument[0])] = true
        }
      }
    }
    for pin in cell.pins {
      let pin_path = path + "/pin:" + pin.name
      duplicate_properties(pin.source, pin_path, findings)
      match pin.direction {
        Some(direction) if !["input", "output", "inout", "internal"].contains(
            direction,
          ) =>
          add_finding(
            findings,
            "InvalidDirection",
            pin_path + "/direction",
            "unknown pin direction " + direction,
            simple_position(pin.source, "direction"),
          )
        None =>
          add_finding(
            findings,
            "MissingDirection",
            pin_path,
            "pin has no declared direction",
            pin.source.position,
            severity=Warning,
          )
        _ => ()
      }
      for
        property in [
          ("capacitance", pin.capacitance),
          ("max_capacitance", pin.max_capacitance),
          ("max_transition", pin.max_transition),
        ] {
        if property.1 is Some(value) &&
          (value < 0.0 || value.is_nan() || value.is_inf()) {
          add_finding(
            findings,
            if value.is_nan() || value.is_inf() {
              "NonFiniteNumber"
            } else {
              "NegativePinLimit"
            },
            pin_path + "/" + property.0,
            "capacitance/transition value must be finite and nonnegative",
            simple_position(pin.source, property.0),
          )
        }
      }
      if pin.function is Some(text) {
        check_logic(
          text,
          logic_names,
          pin_path + "/function",
          simple_position(pin.source, "function"),
          findings,
        )
      }
      for timing_group in pin.source.groups("timing") {
        duplicate_properties(timing_group, pin_path + "/timing", findings)
        for item in timing_group.items {
          if item is Section(group) && timing_table_kind(group.kind) {
            duplicate_properties(group, pin_path + "/" + group.kind, findings)
          }
        }
      }
      for arc in pin.timings {
        let arc_path = pin_path + "/timing:" + arc.related_pins.join(" ")
        let self_constraint = arc.timing_type == Some("min_pulse_width") ||
          arc.timing_type == Some("minimum_period")
        if arc.related_pins.is_empty() &&
          !arc.tables.is_empty() &&
          !self_constraint {
          add_finding(
            findings,
            "MissingRelatedPin",
            arc_path,
            "timing arc with tables needs related_pin",
            arc.position,
          )
        }
        for name in arc.related_pins {
          if !pin_names.contains(name) {
            add_finding(
              findings,
              "UnknownRelatedPin",
              arc_path,
              "related pin is undeclared: " + name,
              arc.position,
            )
          }
        }
        if arc.timing_sense is Some(sense) &&
          !["positive_unate", "negative_unate", "non_unate"].contains(sense) {
          add_finding(
            findings,
            "InvalidTimingSense",
            arc_path,
            "unknown timing_sense " + sense,
            arc.position,
          )
        }
        if arc.condition is Some(condition) {
          check_logic(
            condition,
            logic_names,
            arc_path + "/when",
            arc.position,
            findings,
          )
        }
        for table in arc.tables {
          if ["rise_transition", "fall_transition"].contains(table.kind) &&
            table.values.any(value => value < 0.0) {
            add_finding(
              findings,
              "NegativeTransition",
              arc_path + "/" + table.kind,
              "transition table values must be nonnegative",
              table.position,
            )
          }
          validate_table(table) catch {
            error => findings.push(finding(error, arc_path + "/" + table.kind))
          }
          if table.index_1.any(v => v < 0.0) || table.index_2.any(v => v < 0.0) {
            add_finding(
              findings,
              "NegativeAxis",
              arc_path + "/" + table.kind,
              "transition/load axis contains negative coordinates",
              table.position,
            )
          }
        }
      }
    }
  }
  findings.sort_by((a, b) => {
    let path_order = lexical_compare(a.path, b.path)
    if path_order != 0 {
      path_order
    } else {
      let code_order = lexical_compare(a.code, b.code)
      if code_order != 0 {
        code_order
      } else {
        a.position.offset.compare(b.position.offset)
      }
    }
  })
  findings
}

///|
pub fn findings_json(findings : Array[Finding]) -> Json {
  findings
  .map(f => {
    (
      {
        "code": f.code.to_json(),
        "severity": (if f.severity == Error { "error" } else { "warning" }).to_json(),
        "path": f.path.to_json(),
        "message": f.message.to_json(),
        "line": f.position.line.to_json(),
        "column": f.position.column.to_json(),
      } : Json)
  })
  .to_json()
}

///|
pub fn lint_json(library : Library) -> Json {
  let findings = lint_library(library)
  let errors = findings.filter(f => f.severity == Error).length()
  {
    "schema": "moonliberty.lint.v1",
    "library": library.name.to_json(),
    "valid": (errors == 0).to_json(),
    "errors": errors.to_json(),
    "warnings": findings.filter(f => f.severity == Warning).length().to_json(),
    "findings": findings_json(findings),
  }
}
