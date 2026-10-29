///|
fn generated_library(cells : Int32) -> String {
  let out = StringBuilder()
  out.write_string(
    "library(benchmark){time_unit:\"1ns\";capacitive_load_unit(1,pf);",
  )
  for i in 0..<cells {
    out.write_string(
      "cell(C\{i}){area:1;pin(A){direction:input;}pin(Y){direction:output;function:\"!A\";}}",
    )
  }
  out.write_string("}")
  out.to_string()
}

///|
test "Liberty parser and typed model on synthetic 1000-cell input" (
  b : @bench.T,
) {
  let text = generated_library(1000)
  b.bench(
    name="parse 1000 cells",
    () => b.keep(try! @liberty.parse_liberty(text)),
    count=5,
  )
  b.bench(
    name="model 1000 cells",
    () => b.keep(try! @liberty.load_library(text)),
    count=5,
  )
}

///|
test "validated 7 by 7 NLDM interpolation" (b : @bench.T) {
  let axis = Array::makei(7, i => i.to_double())
  let values = Array::makei(49, i => {
    (i / 7).to_double() * 2.0 + (i % 7).to_double() * 3.0
  })
  let table : @liberty.Table = {
    kind: "cell_rise",
    template_name: "generated",
    variable_1: Some("input_net_transition"),
    variable_2: Some("total_output_net_capacitance"),
    index_1: axis,
    index_2: axis.copy(),
    values,
    position: { offset: 0, line: 1, column: 1, },
  }
  b.bench(name="validated lookup 7x7", () => {
    b.keep(try! @liberty.lookup_table(table, 2.25, y=3.75))
  })
}
