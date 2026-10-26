///|
pub(all) enum RangePolicy {
  Reject
  Clamp
  Extrapolate
} derive(Eq, Debug)

///|
pub(all) struct Table {
  kind : String
  template_name : String
  variable_1 : String?
  variable_2 : String?
  index_1 : Array[Double]
  index_2 : Array[Double]
  values : Array[Double]
  position : Position
} derive(Eq, Debug)

///|
pub(all) struct Lookup {
  value : Double
  clamped : Bool
  extrapolated : Bool
  x_interval : Int
  y_interval : Int?
} derive(Eq, Debug)

///|
pub fn validate_table(table : Table) -> Unit raise LibertyError {
  let x = table.index_1
  let y = table.index_2
  if x.length() > 10000 || y.length() > 10000 || table.values.length() > 1000000 {
    raise failure(
      "TableLimit",
      "table exceeds supported axis/value budget",
      table.position,
    )
  }
  if x.is_empty() && !y.is_empty() {
    raise failure("TableShape", "index_2 requires index_1", table.position)
  }
  let rows = if x.is_empty() { 1 } else { x.length() }
  let columns = if y.is_empty() { 1 } else { y.length() }
  if rows > 1000000 / columns || table.values.length() != rows * columns {
    raise failure(
      "TableShape",
      "value count does not match axis dimensions",
      table.position,
    )
  }
  for axis in [x, y] {
    for i = 0; i < axis.length(); i = i + 1 {
      if axis[i].is_nan() || axis[i].is_inf() {
        raise failure("NonFiniteNumber", "axis must be finite", table.position)
      }
      if i > 0 && axis[i] <= axis[i - 1] {
        raise failure(
          "NonIncreasingAxis",
          "axis must be strictly increasing",
          table.position,
        )
      }
    }
  }
  for value in table.values {
    if value.is_nan() || value.is_inf() {
      raise failure(
        "NonFiniteNumber",
        "table values must be finite",
        table.position,
      )
    }
  }
}

///|
pub fn read_table(group : Group, template? : Group) -> Table raise LibertyError {
  let reference = group.name()
  if reference.is_empty() {
    raise failure(
      "MissingTemplate",
      "table needs one template name",
      group.position,
    )
  }
  if reference != "scalar" && template == None {
    raise failure(
      "MissingTemplate",
      "unknown lookup template: " + reference,
      group.position,
    )
  }
  if template is Some(t) && t.name() != reference {
    raise failure(
      "TemplateMismatch",
      "supplied template name differs from table reference",
      group.position,
    )
  }
  if group.complex("index_3") != None ||
    (
      template is Some(t) &&
      (t.text("variable_3") != None || t.complex("index_3") != None)
    ) {
    // Unsupported evaluation must not hide malformed 3-D format data.
    ignore(read_table_data(group, template?))
    raise failure(
      "UnsupportedDimension",
      "only scalar, 1D and 2D lookup tables are supported",
      group.position,
    )
  }
  let x = match vector(group, "index_1") {
    Some(values) => values
    None =>
      match template {
        Some(t) =>
          match vector(t, "index_1") {
            Some(v) => v
            None => []
          }
        None => []
      }
  }
  let y = match vector(group, "index_2") {
    Some(values) => values
    None =>
      match template {
        Some(t) =>
          match vector(t, "index_2") {
            Some(v) => v
            None => []
          }
        None => []
      }
  }
  let arguments = match group.complex("values") {
    Some(arguments) if !arguments.is_empty() => arguments
    _ =>
      raise failure(
        "MissingValues",
        "lookup table requires values(...)",
        group.position,
      )
  }
  let rows = arguments.map(argument => {
    number_list(argument, position=group.position)
  })
  if reference == "scalar" && (!x.is_empty() || !y.is_empty()) {
    raise failure(
      "TableShape",
      "scalar template must not have axes",
      group.position,
    )
  }
  if y.is_empty() && rows.length() != 1 {
    raise failure(
      "TableShape",
      "scalar and 1D tables require exactly one quoted row",
      group.position,
    )
  }
  if !y.is_empty() &&
    (rows.length() != x.length() || rows.any(row => row.length() != y.length())) {
    raise failure(
      "TableShape",
      "2D values must have one row per index_1 and one column per index_2",
      group.position,
    )
  }
  let values = []
  for row in rows {
    values.append(row)
  }
  let table : Table = {
    kind: group.kind,
    template_name: reference,
    variable_1: match template {
      Some(t) => t.text("variable_1")
      None => None
    },
    variable_2: match template {
      Some(t) => t.text("variable_2")
      None => None
    },
    index_1: x,
    index_2: y,
    values,
    position: group.position,
  }
  validate_table(table)
  table
}

///|
priv struct Interval {
  low : Int
  high : Int
  fraction : Double
  outside : Bool
}

///|
fn locate(
  axis : Array[Double],
  value : Double,
  policy : RangePolicy,
  pos : Position,
) -> Interval raise LibertyError {
  let last = axis.length() - 1
  let outside = value < axis[0] || value > axis[last]
  if outside && policy == Reject {
    raise failure(
      "OutOfRange", "query coordinate lies outside lookup axis", pos,
    )
  }
  if last == 0 {
    if outside && policy == Extrapolate {
      raise failure(
        "InsufficientAxis", "cannot extrapolate a singleton axis", pos,
      )
    }
    return { low: 0, high: 0, fraction: 0.0, outside, }
  }
  let coordinate = if policy == Clamp {
    if value < axis[0] {
      axis[0]
    } else if value > axis[last] {
      axis[last]
    } else {
      value
    }
  } else {
    value
  }
  let mut low = 0
  let mut high = last
  while high - low > 1 {
    let middle = low + (high - low) / 2
    if axis[middle] <= coordinate {
      low = middle
    } else {
      high = middle
    }
  }
  let difference = coordinate - axis[low]
  let span = axis[high] - axis[low]
  let fraction = if difference.is_inf() || span.is_inf() {
    (coordinate / 2.0 - axis[low] / 2.0) / (axis[high] / 2.0 - axis[low] / 2.0)
  } else {
    difference / span
  }
  if fraction.is_inf() || fraction.is_nan() {
    raise failure("NumericRange", "interpolation weight is not finite", pos)
  }
  { low, high, fraction, outside, }
}

///|
fn interpolate(a : Double, b : Double, fraction : Double) -> Double {
  if fraction == 0.0 {
    return a
  }
  if fraction == 1.0 {
    return b
  }
  if fraction > 0.0 && fraction < 1.0 {
    return (1.0 - fraction) * a + fraction * b
  }
  let difference = b - a
  if !difference.is_inf() {
    return a + difference * fraction
  }
  // Opposite extreme endpoints can overflow the difference even when a small
  // extrapolation beyond one endpoint is representable.
  if fraction > 1.0 {
    let extra = fraction - 1.0
    b + (b * extra - a * extra)
  } else {
    a + (b * fraction - a * fraction)
  }
}

///|
pub fn lookup_table(
  table : Table,
  x : Double,
  y? : Double,
  policy? : RangePolicy = Reject,
) -> Lookup raise LibertyError {
  validate_table(table)
  if x.is_nan() || x.is_inf() || (y is Some(v) && (v.is_nan() || v.is_inf())) {
    raise failure(
      "NonFiniteNumber",
      "query coordinates must be finite",
      table.position,
    )
  }
  if table.index_1.is_empty() {
    if y != None {
      raise failure(
        "UnexpectedCoordinate",
        "scalar table has no second coordinate",
        table.position,
      )
    }
    return {
      value: table.values[0],
      clamped: false,
      extrapolated: false,
      x_interval: 0,
      y_interval: None,
    }
  }
  let ix = locate(table.index_1, x, policy, table.position)
  let iy = if table.index_2.is_empty() {
    if y != None {
      raise failure(
        "UnexpectedCoordinate",
        "1D table has no second coordinate",
        table.position,
      )
    }
    None
  } else {
    match y {
      Some(value) => Some(locate(table.index_2, value, policy, table.position))
      None =>
        raise failure(
          "MissingCoordinate",
          "2D table requires two coordinates",
          table.position,
        )
    }
  }
  let value = match iy {
    None =>
      interpolate(table.values[ix.low], table.values[ix.high], ix.fraction)
    Some(iy) => {
      let columns = table.index_2.length()
      let lower = interpolate(
        table.values[ix.low * columns + iy.low],
        table.values[ix.high * columns + iy.low],
        ix.fraction,
      )
      let upper = interpolate(
        table.values[ix.low * columns + iy.high],
        table.values[ix.high * columns + iy.high],
        ix.fraction,
      )
      interpolate(lower, upper, iy.fraction)
    }
  }
  if value.is_inf() || value.is_nan() {
    raise failure(
      "NumericRange",
      "interpolated value is not finite",
      table.position,
    )
  }
  let outside = ix.outside || (iy is Some(v) && v.outside)
  {
    value,
    clamped: outside && policy == Clamp,
    extrapolated: outside && policy == Extrapolate,
    x_interval: ix.low,
    y_interval: iy.map(i => i.low),
  }
}
