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
  x_interval : Int32
  y_interval : Int32?
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
  // One format validator prevents the evaluator and compatibility report from
  // disagreeing about absent, empty, inherited or three-dimensional axes.
  let data = read_table_data(group, template?)
  if data.axes.length() > 2 {
    raise failure(
      "UnsupportedDimension",
      "only scalar, 1D and 2D lookup tables are supported",
      group.position,
    )
  }
  let values = []
  for row in data.rows {
    values.append(row)
  }
  let table : Table = {
    kind: group.kind,
    template_name: data.template_name,
    variable_1: match template {
      Some(t) => t.text("variable_1")
      None => None
    },
    variable_2: match template {
      Some(t) => t.text("variable_2")
      None => None
    },
    index_1: data.axes.get(0).unwrap_or([]),
    index_2: data.axes.get(1).unwrap_or([]),
    values,
    position: group.position,
  }
  validate_table(table)
  table
}

///|
priv struct Interval {
  low : Int32
  high : Int32
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
    let delta = difference * fraction
    if delta.is_inf() {
      // A finite endpoint can cancel an overflowing product. Scale only this
      // exceptional path; the final finite-result check still rejects overflow.
      return (a / 2.0 + difference * (fraction / 2.0)) * 2.0
    }
    return a + delta
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
  policy~ : RangePolicy = Reject,
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
