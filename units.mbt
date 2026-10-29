///|
pub(all) enum Quantity {
  Time
  Capacitance
  Voltage
} derive(Eq, Debug)

///|
pub(all) struct Units {
  time_seconds : Double
  capacitance_farads : Double
  voltage_volts : Double?
} derive(Eq, Debug)

///|
pub fn finite_number(
  text : String,
  position~ : Position = no_position(),
) -> Double raise LibertyError {
  let clean = text.trim()
  if clean.is_empty() {
    raise failure("InvalidNumber", "empty numeric value", position)
  }
  let value = @string.parse_double(clean) catch {
    _ =>
      raise failure("InvalidNumber", "invalid numeric value: " + text, position)
  }
  if value.is_nan() || value.is_inf() {
    raise failure("NonFiniteNumber", "finite numeric value required", position)
  }
  value
}

///|
pub fn parse_unit(
  text : String,
  quantity : Quantity,
) -> Double raise LibertyError {
  let value = text.trim().to_owned()
  let suffixes : Array[(String, Double)] = match quantity {
    Time =>
      [
        ("ms", 1.0e-3),
        ("us", 1.0e-6),
        ("ns", 1.0e-9),
        ("ps", 1.0e-12),
        ("fs", 1.0e-15),
        ("s", 1.0),
      ]
    Capacitance =>
      [
        ("uF", 1.0e-6),
        ("nF", 1.0e-9),
        ("pF", 1.0e-12),
        ("fF", 1.0e-15),
        ("uf", 1.0e-6),
        ("nf", 1.0e-9),
        ("pf", 1.0e-12),
        ("ff", 1.0e-15),
        ("F", 1.0),
        ("f", 1.0),
      ]
    Voltage =>
      [
        ("mV", 1.0e-3),
        ("uV", 1.0e-6),
        ("mv", 1.0e-3),
        ("uv", 1.0e-6),
        ("V", 1.0),
        ("v", 1.0),
      ]
  }
  for entry in suffixes {
    if value.has_suffix(entry.0) {
      let prefix = value[0:value.length() - entry.0.length()].to_owned()
      let factor = finite_number(prefix)
      let scaled = factor * entry.1
      if factor <= 0.0 || scaled <= 0.0 || scaled.is_nan() || scaled.is_inf() {
        raise failure(
          "InvalidUnit",
          "unit scale must be positive and finite",
          no_position(),
        )
      }
      return scaled
    }
  }
  raise failure("UnsupportedUnit", "unsupported unit: " + text, no_position())
}

///|
/// Validate public, possibly caller-constructed unit scales before arithmetic.
pub fn validate_units(units : Units) -> Unit raise LibertyError {
  let scales = [units.time_seconds, units.capacitance_farads]
  if units.voltage_volts is Some(voltage) {
    scales.push(voltage)
  }
  if scales.any(scale => scale <= 0.0 || scale.is_nan() || scale.is_inf()) {
    raise failure(
      "InvalidUnit",
      "all declared SI scales must be positive and finite",
      no_position(),
    )
  }
}

///|
pub fn read_units(root : Group) -> Units raise LibertyError {
  let time = match root.text("time_unit") {
    Some(text) => parse_unit(text, Time)
    None =>
      raise failure(
        "MissingUnit",
        "time_unit is required for SI timing queries",
        root.position,
      )
  }
  let capacitance = match root.complex("capacitive_load_unit") {
    Some(args) if args.length() == 2 &&
      args[0].length() == 1 &&
      args[1].length() == 1 =>
      parse_unit(atom_text(args[0][0]) + atom_text(args[1][0]), Capacitance)
    _ =>
      raise failure(
        "MissingUnit",
        "capacitive_load_unit(number,unit) is required",
        root.position,
      )
  }
  let voltage = match root.text("voltage_unit") {
    Some(text) => Some(parse_unit(text, Voltage))
    None => None
  }
  {
    time_seconds: time,
    capacitance_farads: capacitance,
    voltage_volts: voltage,
  }
}

///|
pub fn number_list(
  atoms : Array[Atom],
  position~ : Position = no_position(),
) -> Array[Double] raise LibertyError {
  if atoms.length() != 1 {
    raise failure(
      "ExpectedNumbers", "expected one numeric atom or a quoted comma-separated row",
      position,
    )
  }
  let raw = atom_text(atoms[0])
  let numbers = []
  for part in raw.split(",") {
    numbers.push(finite_number(part.to_owned(), position~))
  }
  numbers
}

///|
fn vector(group : Group, name : String) -> Array[Double]? raise LibertyError {
  match group.complex(name) {
    None => None
    Some(arguments) => {
      let numbers = []
      for argument in arguments {
        numbers.append(number_list(argument, position=group.position))
      }
      Some(numbers)
    }
  }
}
