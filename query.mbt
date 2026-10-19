///|
pub(all) struct TimingQuery {
  cell : String
  pin : String
  related_pin : String
  table_kind : String
  condition : String?
  slew_seconds : Double
  load_farads : Double
  seconds : Double
  raw_value : Double
  clamped : Bool
  extrapolated : Bool
} derive(Eq, Debug)

///|
fn axis_coordinate(
  variable : String?,
  slew : Double,
  load : Double,
  units : Units,
  pos : Position,
) -> Double raise LibertyError {
  match variable {
    Some("input_net_transition") | Some("input_transition_time") =>
      slew / units.time_seconds
    Some("total_output_net_capacitance") => load / units.capacitance_farads
    _ =>
      raise failure(
        "UnsupportedAxis", "SI delay queries require input transition or total output capacitance axes",
        pos,
      )
  }
}

///|
pub fn query_timing(
  library : Library,
  cell_name : String,
  pin_name : String,
  related_pin : String,
  table_kind : String,
  slew_seconds : Double,
  load_farads : Double,
  condition? : String,
  policy? : RangePolicy = Reject,
) -> TimingQuery raise LibertyError {
  if !["cell_rise", "cell_fall", "rise_transition", "fall_transition"].contains(
      table_kind,
    ) {
    raise failure(
      "UnsupportedQuery",
      "query supports combinational delay and transition tables",
      library.source.position,
    )
  }
  if slew_seconds < 0.0 ||
    load_farads < 0.0 ||
    slew_seconds.is_nan() ||
    slew_seconds.is_inf() ||
    load_farads.is_nan() ||
    load_farads.is_inf() {
    raise failure(
      "InvalidCoordinate",
      "slew seconds and load farads must be finite and nonnegative",
      no_position(),
    )
  }
  let errors = lint_library(library).filter(f => f.severity == Error)
  if !errors.is_empty() {
    raise failure(
      "InvalidLibrary",
      errors[0].code + ": " + errors[0].message,
      errors[0].position,
    )
  }
  let units = match library.units {
    Some(units) => units
    None =>
      raise failure(
        "MissingUnit",
        "SI queries require explicit supported time and capacitance units",
        library.source.position,
      )
  }
  let cell = match library.cell(cell_name) {
    Some(cell) => cell
    None =>
      raise failure(
        "MissingCell",
        "cell not found: " + cell_name,
        library.source.position,
      )
  }
  let pin = match cell.pin(pin_name) {
    Some(pin) => pin
    None =>
      raise failure(
        "MissingPin",
        "pin not found: " + pin_name,
        cell.source.position,
      )
  }
  let candidates = pin.timings.filter(arc => {
    arc.related_pins.contains(related_pin) &&
    (
      arc.timing_type == None ||
      ["combinational", "combinational_rise", "combinational_fall"].contains(
        arc.timing_type.unwrap(),
      )
    ) &&
    arc.tables.any(table => table.kind == table_kind)
  })
  if candidates.is_empty() {
    raise failure(
      "MissingArc",
      "no matching combinational timing arc/table",
      pin.source.position,
    )
  }
  let selected = candidates.filter(arc => arc.condition == condition)
  if selected.is_empty() && condition == None {
    raise failure(
      "ConditionRequired",
      "only conditional arcs match; select an exact when expression",
      pin.source.position,
    )
  }
  if selected.is_empty() {
    raise failure(
      "MissingCondition",
      "no arc matches the exact when expression",
      pin.source.position,
    )
  }
  let matches = []
  for arc in selected {
    for table in arc.tables {
      if table.kind == table_kind {
        matches.push(table)
      }
    }
  }
  if matches.length() != 1 {
    raise failure(
      "AmbiguousArc",
      "multiple matching arcs/tables; refuse arbitrary selection",
      pin.source.position,
    )
  }
  let table = matches[0]
  let x = if table.index_1.is_empty() {
    0.0
  } else {
    axis_coordinate(
      table.variable_1,
      slew_seconds,
      load_farads,
      units,
      table.position,
    )
  }
  let y = if table.index_2.is_empty() {
    None
  } else {
    Some(
      axis_coordinate(
        table.variable_2,
        slew_seconds,
        load_farads,
        units,
        table.position,
      ),
    )
  }
  let lookup = lookup_table(table, x, y?, policy~)
  let seconds = lookup.value * units.time_seconds
  if seconds.is_nan() || seconds.is_inf() {
    raise failure(
      "NumericRange",
      "normalized query result is not finite",
      table.position,
    )
  }
  {
    cell: cell_name,
    pin: pin_name,
    related_pin,
    table_kind,
    condition,
    slew_seconds,
    load_farads,
    seconds,
    raw_value: lookup.value,
    clamped: lookup.clamped,
    extrapolated: lookup.extrapolated,
  }
}

///|
pub fn query_json(query : TimingQuery) -> Json {
  {
    "schema": "moonliberty.query.v1",
    "cell": query.cell.to_json(),
    "pin": query.pin.to_json(),
    "related_pin": query.related_pin.to_json(),
    "table": query.table_kind.to_json(),
    "when": nullable_text(query.condition),
    "slew_seconds": query.slew_seconds.to_json(),
    "load_farads": query.load_farads.to_json(),
    "seconds": query.seconds.to_json(),
    "value_in_library_time_unit": query.raw_value.to_json(),
    "clamped": query.clamped.to_json(),
    "extrapolated": query.extrapolated.to_json(),
  }
}
