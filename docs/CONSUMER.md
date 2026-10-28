# 0.4.2 发布包的独立消费者验证

2026-10-28，moon publish 返回 200 OK。发布源码基准 2f26a066509eaaf2662e4c94f72d83efef173d4e，其[完整 CI](https://github.com/SongYZZZ/moon-liberty/actions/runs/40621122563)已通过；标签 v0.4.2 指向该基准。发布归档 SHA-256：18b77203d0a04fd8be34ea76941b7b3f06ecc5b03539dd884465c5c586431b8d。

独立目录 D:/Dev/Temp/moon-liberty-consumer-042-20261028 精确依赖 SongYZZZ/moon-liberty@0.4.2，由 moon update 实际从注册表下载，未使用本地路径。native 严格检查及实际运行、JS/Wasm GC 严格检查全部通过。49 个 .mbt 文件及根 moon.mod/moon.pkg 与发布源码逐字节一致；归档不含依赖缓存、构建、下载工具或 artifacts。

保留 0.4.1 的公共 API 消费代码，并实际验证 BOM 根文件/片段、紧邻续行、注释内 NUL 拒绝、statetable 内部节点引用及有限外推。成功输出仍为既有消费者摘要，新增断言均在输出前执行。实际主程序：

```moonbit
///|
fn main {
  let input = "\uFEFFlibrary(x){time_unit:\"1ns\";capacitive_load_unit(1,pf);cell(C){pin(A,B){direction:input;}pin(Y,Z){direction:output;function:\"A & B\";timing(){related_pin:\"A B\";cell_rise(scalar){values(\"0.03\");}}}}}"
  let library = @liberty.load_library(input, model_limits={
    max_pins: 100,
    max_work: 1000,
  }) catch {
    e => abort(e.render())
  }
  if library.inventory().pins != 4 {
    abort("shared pin expansion failed")
  }
  let answer = @liberty.query_timing(
    library, "C", "Z", "B", "cell_rise", 0.0, 0.0,
  ) catch {
    e => abort(e.render())
  }
  if (answer.seconds - 3.0e-11).abs() > 1.0e-23 {
    abort("alias SI query failed")
  }
  let report = @liberty.compatibility_report(library.source) catch {
    e => abort(e.render())
  }
  if report.complete_conformance {
    abort("incomplete standard claimed complete")
  }
  let expression = @liberty.parse_logic("\"0\"") catch {
    e => abort(e.render())
  }
  let formatted = @liberty.format_logic(expression) catch {
    e => abort(e.render())
  }
  let reparsed = @liberty.parse_logic(formatted) catch {
    e => abort(e.render())
  }
  if expression != reparsed {
    abort("quoted signal identity lost")
  }
  @liberty.validate_units({
    time_seconds: 1.0e-9,
    capacitance_farads: 1.0e-12,
    voltage_volts: None,
  }) catch {
    e => abort(e.render())
  }
  let root = @liberty.parse_liberty(
    "library(x){cell(C){type(W){bit_width:1;}bus(D){bus_type:W;pin(D[0]){}}}}",
  ) catch {
    e => abort(e.render())
  }
  if @liberty.standard_findings(root).any(f => f.severity == @liberty.Error) {
    abort("local type rejected")
  }
  let invalid = @liberty.parse_liberty(
    "library(x){lu_table_template(T){}cell_rise(T){values(\"1\");}}",
  ) catch {
    e => abort(e.render())
  }
  try
    @liberty.read_table(
      invalid.groups("cell_rise")[0],
      template=invalid.groups("lu_table_template")[0],
    )
  catch {
    @liberty.LibertyError(code, _, _) =>
      if code != "TableShape" {
        abort("wrong missing-axis diagnostic")
      }
  } noraise {
    _ => abort("missing axes accepted as scalar")
  }
  let sr = @liberty.parse_liberty(
    "library(x){cell(C){latch(Q,QN){clear:\"0\";preset:\"1\";clear_preset_var1:L;}}}",
  ) catch {
    e => abort(e.render())
  }
  if @liberty.standard_findings(sr).any(f => f.severity == @liberty.Error) {
    abort("SR latch incorrectly rejected")
  }
  let continued = @liberty.load_library("library(x){cell(C){area:1\\\n;}}") catch {
    e => abort(e.render())
  }
  if continued.cells[0].area != Some(1.0) {
    abort("adjacent continuation rejected")
  }
  let states = @liberty.load_library(
    "library(x){time_unit:\"1ns\";capacitive_load_unit(1,pf);cell(C){pin(A){direction:input;}statetable(\"A\",\"IQ\"){table:\"L:-:L,H:-:H\";}pin(Y){direction:output;function:\"IQ\";}}}",
  ) catch {
    e => abort(e.render())
  }
  if @liberty.lint_library(states).any(f => f.severity == @liberty.Error) {
    abort("statetable reference rejected")
  }
  let sample : @liberty.Table = {
    kind: "cell_rise",
    template_name: "T",
    variable_1: Some("input_net_transition"),
    variable_2: None,
    index_1: [0.0, 1.0],
    index_2: [],
    values: [-1.0e308, 0.0],
    position: { offset: 0, line: 1, column: 1, },
  }
  let extrapolated = @liberty.lookup_table(
    sample,
    2.0,
    policy=@liberty.Extrapolate,
  ) catch {
    e => abort(e.render())
  }
  if extrapolated.value != 1.0e308 {
    abort("finite extrapolation failed")
  }
  try @liberty.tokenize("/*\u0000*/") catch {
    @liberty.LibertyError(code, _, _) =>
      if code != "InvalidCharacter" {
        abort("wrong NUL rejection")
      }
  } noraise {
    _ => abort("comment concealed NUL")
  }
  let expanded = @liberty.parse_liberty_sources(
    "\uFEFFlibrary(x){include_file(c.inc);}",
    Map([("c.inc", "\uFEFFcell(C){}")]),
  ) catch {
    e => abort(e.render())
  }
  if expanded.groups("cell").length() != 1 {
    abort("BOM fragment rejected")
  }
  println(
    "Published 0.4.2 consumer passed: shared pins, SI query, quoted logic, units, local types",
  )
}
```

验证命令：moon update、moon check --deny-warn、moon run .、moon check --target js --deny-warn、moon check --target wasm-gc --deny-warn。机读记录在本地 artifacts/publication-042.json，上一轮记录见 [0.4.1 消费者验证](history/CONSUMER_0_4_1.md)。接口与安装验证不等同于完整标准兼容。
