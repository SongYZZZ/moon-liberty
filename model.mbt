///|
pub(all) struct TimingArc {
  related_pins : Array[String]
  timing_type : String?
  timing_sense : String?
  condition : String?
  tables : Array[Table]
  position : Position
} derive(Debug)

///|
pub(all) struct Pin {
  name : String
  direction : String?
  capacitance : Double?
  max_capacitance : Double?
  max_transition : Double?
  function : String?
  timings : Array[TimingArc]
  source : Group
} derive(Debug)

///|
pub(all) struct Cell {
  name : String
  area : Double?
  pins : Array[Pin]
  source : Group
} derive(Debug)

///|
pub(all) struct Library {
  name : String
  units : Units?
  cells : Array[Cell]
  templates : Array[Group]
  findings : Array[Finding]
  source : Group
} derive(Debug)

///|
pub(all) struct Inventory {
  cells : Int
  pins : Int
  arcs : Int
  tables : Int
  errors : Int
  warnings : Int
} derive(Eq, Debug)

///|
fn finding(
  error : LibertyError,
  path : String,
  severity? : Severity = Error,
) -> Finding {
  let LibertyError(code, message, position) = error
  { code, severity, path, message, position, }
}

///|
fn simple_position(group : Group, key : String) -> Position {
  for item in group.items {
    if item is Attribute(name, _, pos) && name == key {
      return pos
    }
  }
  group.position
}

///|
fn optional_number(
  group : Group,
  key : String,
  path : String,
  findings : Array[Finding],
) -> Double? {
  match group.text(key) {
    None => None
    Some(text) => {
      let value = finite_number(text, position=simple_position(group, key)) catch {
        error => {
          findings.push(finding(error, path + "/" + key))
          return None
        }
      }
      Some(value)
    }
  }
}

///|
fn words(value : String) -> Array[String] {
  let result = []
  let mut start = 0
  for i = 0; i <= value.length(); i = i + 1 {
    if i == value.length() || whitespace(value[i]) {
      if i > start {
        result.push(value[start:i].to_owned())
      }
      start = i + 1
    }
  }
  result
}

///|
fn timing_table_kind(kind : String) -> Bool {
  [
    "cell_rise", "cell_fall", "rise_transition", "fall_transition", "rise_constraint",
    "fall_constraint",
  ].contains(kind)
}

///|
pub fn build_library(root : Group) -> Library raise LibertyError {
  if root.kind != "library" || root.name().is_empty() {
    raise failure(
      "InvalidRoot",
      "typed model needs one named library",
      root.position,
    )
  }
  let findings = []
  let units = Some(read_units(root)) catch {
    error => {
      findings.push(finding(error, root.name(), severity=Warning))
      None
    }
  }
  let templates = root.groups("lu_table_template")
  let by_name : Map[String, Group] = Map([])
  for template in templates {
    if by_name.contains(template.name()) {
      findings.push({
        code: "DuplicateTemplate",
        severity: Error,
        path: root.name() + "/" + template.name(),
        message: "lookup template name is duplicated",
        position: template.position,
      })
    } else {
      by_name[template.name()] = template
    }
  }
  let cells = []
  for cell in root.groups("cell") {
    let cell_path = root.name() + "/cell:" + cell.name()
    let pins = []
    for pin in cell.groups("pin") {
      let pin_path = cell_path + "/pin:" + pin.name()
      let timings = []
      for timing in pin.groups("timing") {
        let tables = []
        for node in timing.items {
          if node is Section(group) && timing_table_kind(group.kind) {
            let table = read_table(group, template?=by_name.get(group.name())) catch {
              error => {
                let LibertyError(code, _, _) = error
                findings.push(
                  finding(
                    error,
                    pin_path + "/" + group.kind,
                    severity=if code == "UnsupportedDimension" {
                      Warning
                    } else {
                      Error
                    },
                  ),
                )
                continue
              }
            }
            tables.push(table)
          }
        }
        timings.push({
          related_pins: match timing.text("related_pin") {
            Some(value) => words(value)
            None => []
          },
          timing_type: timing.text("timing_type"),
          timing_sense: timing.text("timing_sense"),
          condition: timing.text("when"),
          tables,
          position: timing.position,
        })
      }
      pins.push({
        name: pin.name(),
        direction: pin.text("direction"),
        capacitance: optional_number(pin, "capacitance", pin_path, findings),
        max_capacitance: optional_number(
          pin, "max_capacitance", pin_path, findings,
        ),
        max_transition: optional_number(
          pin, "max_transition", pin_path, findings,
        ),
        function: pin.text("function"),
        timings,
        source: pin,
      })
    }
    cells.push({
      name: cell.name(),
      area: optional_number(cell, "area", cell_path, findings),
      pins,
      source: cell,
    })
  }
  { name: root.name(), units, cells, templates, findings, source: root, }
}

///|
pub fn load_library(
  text : String,
  limits? : Limits = Limits::default(),
) -> Library raise LibertyError {
  build_library(parse_liberty(text, limits~))
}

///|
pub fn Library::cell(self : Library, name : String) -> Cell? {
  self.cells.iter().find_first(cell => cell.name == name)
}

///|
pub fn Cell::pin(self : Cell, name : String) -> Pin? {
  self.pins.iter().find_first(pin => pin.name == name)
}

///|
pub fn Library::inventory(self : Library) -> Inventory {
  let mut pins = 0
  let mut arcs = 0
  let mut tables = 0
  for cell in self.cells {
    pins += cell.pins.length()
    for pin in cell.pins {
      arcs += pin.timings.length()
      for timing in pin.timings {
        tables += timing.tables.length()
      }
    }
  }
  {
    cells: self.cells.length(),
    pins,
    arcs,
    tables,
    errors: self.findings.filter(f => f.severity == Error).length(),
    warnings: self.findings.filter(f => f.severity == Warning).length(),
  }
}

///|
fn nullable_number(value : Double?) -> Json {
  match value {
    Some(number) => number.to_json()
    None => Json::null()
  }
}

///|
fn nullable_text(value : String?) -> Json {
  match value {
    Some(text) => text.to_json()
    None => Json::null()
  }
}

///|
pub fn inventory_json(library : Library) -> Json {
  let inventory = library.inventory()
  {
    "schema": "moonliberty.inventory.v1",
    "library": library.name.to_json(),
    "delay_model": nullable_text(library.source.text("delay_model")),
    "cells": inventory.cells.to_json(),
    "pins": inventory.pins.to_json(),
    "arcs": inventory.arcs.to_json(),
    "tables": inventory.tables.to_json(),
    "model_errors": inventory.errors.to_json(),
    "model_warnings": inventory.warnings.to_json(),
    "time_unit_seconds": nullable_number(
      library.units.map(units => units.time_seconds),
    ),
    "capacitance_unit_farads": nullable_number(
      library.units.map(units => units.capacitance_farads),
    ),
    "cell_names": library.cells.map(cell => cell.name).to_json(),
  }
}
