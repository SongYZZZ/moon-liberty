///|
/// Format representation of scalar through 3-D tables, without physical evaluation.
/// Rows of a 3-D table follow (index_1, index_2), with index_3 inside each row.
pub(all) struct TableData {
  kind : String
  template_name : String
  axes : Array[Array[Double]]
  rows : Array[Array[Double]]
  position : Position
} derive(Eq, Debug)

///|
pub extend TableData with Eq::{equal, not_equal}

///|
pub extend TableData with @debug.Debug::{to_repr}

///|
pub fn validate_table_data(data : TableData) -> Unit raise LibertyError {
  if data.axes.length() > 3 {
    raise failure(
      "UnsupportedDimension",
      "format table supports up to three axes",
      data.position,
    )
  }
  let mut count = 1
  for axis in data.axes {
    if axis.is_empty() {
      raise failure(
        "TableShape",
        "table axes must be nonempty and contiguous",
        data.position,
      )
    }
    if axis.length() > 10000 || count > 1000000 / axis.length() {
      raise failure(
        "TableLimit",
        "table exceeds axis/value budget",
        data.position,
      )
    }
    count *= axis.length()
    for i = 0; i < axis.length(); i = i + 1 {
      if axis[i].is_nan() || axis[i].is_inf() {
        raise failure("NonFiniteNumber", "axis must be finite", data.position)
      }
      if i > 0 && axis[i] <= axis[i - 1] {
        raise failure(
          "NonIncreasingAxis",
          "axis must be strictly increasing",
          data.position,
        )
      }
    }
  }
  let columns = if data.axes.is_empty() {
    1
  } else {
    data.axes[data.axes.length() - 1].length()
  }
  if data.rows.length() != count / columns ||
    data.rows.any(row => row.length() != columns) {
    raise failure(
      "TableShape",
      "quoted rows do not match table dimensions",
      data.position,
    )
  }
  for row in data.rows {
    for value in row {
      if value.is_nan() || value.is_inf() {
        raise failure(
          "NonFiniteNumber",
          "table values must be finite",
          data.position,
        )
      }
    }
  }
}

///|
/// Read and validate format data independently of the scalar/1-D/2-D evaluator.
pub fn read_table_data(
  group : Group,
  template? : Group,
) -> TableData raise LibertyError {
  let name = group.name()
  if name.is_empty() || (name != "scalar" && template == None) {
    raise failure(
      "MissingTemplate",
      "table needs a known named template or scalar",
      group.position,
    )
  }
  if template is Some(t) && t.name() != name {
    raise failure(
      "TemplateMismatch",
      "supplied template name differs from table reference",
      group.position,
    )
  }
  let axes = []
  let mut gap = false
  for key in ["index_1", "index_2", "index_3"] {
    let override_axis = vector(group, key)
    let axis = match override_axis {
      Some(axis) => Some(axis)
      None =>
        match template {
          Some(t) => vector(t, key)
          None => None
        }
    }
    match axis {
      Some(axis) => {
        if name == "scalar" || gap || axis.is_empty() {
          raise failure(
            "TableShape",
            "scalar has no axes; other axes must be nonempty and contiguous",
            group.position,
          )
        }
        axes.push(axis)
      }
      None => gap = true
    }
  }
  let rows = match group.complex("values") {
    Some(args) if !args.is_empty() =>
      args.map(row => number_list(row, position=group.position))
    _ =>
      raise failure(
        "MissingValues",
        "lookup table requires values(...) with at least one row",
        group.position,
      )
  }
  let data : TableData = {
    kind: group.kind,
    template_name: name,
    axes,
    rows,
    position: group.position,
  }
  validate_table_data(data)
  data
}
