# 0.4.4 发布包的独立消费者验证

2026-10-29，moon publish 返回 200 OK。SDK/core 为 0.10.16+b1a0e846e；发布源码 ff0ecd360c330325ee05d335da30f36b6eac3597，标签 v0.4.4 指向该基准，其[完整远程 CI](https://github.com/SongYZZZ/moon-liberty/actions/runs/40874436465)已通过。归档 SHA-256：f09113e461f409823fbaa53479b562149d7ac644643bfa6cf390e7eb1c1f9542。

独立目录 D:/Dev/Temp/moon-liberty-consumer-044-20261029 精确依赖 SongYZZZ/moon-liberty@0.4.4，日志确认由注册表实际下载；没有本地路径依赖。native 严格检查及实际运行、JS/Wasm GC 严格检查与固定编译器/core 门禁全部通过。49 个 .mbt、根 moon.mod/moon.pkg 及 toolchain.json 与发布源码逐字节一致。发布归档 111 项，不含 .git、SDK、依赖缓存、构建或 artifacts，保留 LICENSE/NOTICE。

保留上一版共享引脚、SI 查询、引号身份、单位、局部类型、缺轴拒绝、SR latch、BOM/include、续行、NUL 和有限外推断言；新增推导总线边界、简单属性形式绕过拒绝及负转换时间外推拒绝。消费者输出成功前全部断言实际执行。

精确依赖清单：

```moonbit
name = "SongYZZZ/liberty-consumer-044"

version = "0.0.1"

preferred_target = "native"

import {
  "SongYZZZ/moon-liberty@0.4.4",
}
```

moon.pkg：

```moonbit
import {
  "SongYZZZ/moon-liberty" @liberty,
}

pkgtype(kind: "executable")
```

在该目录先调用项目 scripts/use-toolchain.ps1 选择固定 SDK，再执行 moon update、moon fmt、moon check --deny-warn、moon run .、moon check --target js --deny-warn、moon check --target wasm-gc --deny-warn；check-toolchain.py --pinned 同样通过。

实际 main.mbt：

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
  let bus = @liberty.parse_liberty(
    "library(x){type(T){bit_width:4;bit_from:6;downto:true;}cell(C){bus(D){bus_type:T;pin(D[2]){}}}}",
  ) catch {
    e => abort(e.render())
  }
  if !@liberty.standard_findings(bus).any(f => f.code == "StandardBusMember") {
    abort("inferred bus bounds ignored")
  }
  let declaration = @liberty.parse_liberty(
    "library(x){define(rank,cell,integer);cell(C){rank(1.5);}}",
  ) catch {
    e => abort(e.render())
  }
  let declared_report = @liberty.compatibility_report(declaration) catch {
    e => abort(e.render())
  }
  if !declared_report.findings.any(f => f.code == "DefinedAttributeForm") {
    abort("declared simple attribute bypassed")
  }
  let transition = @liberty.load_library(
    "library(x){time_unit:\"1ns\";capacitive_load_unit(1,pf);lu_table_template(T){variable_1:input_net_transition;index_1(\"1,2\");}cell(C){pin(A){direction:input;}pin(Y){direction:output;timing(){related_pin:\"A\";rise_transition(T){values(\"0.1,0.3\");}}}}}",
  ) catch {
    e => abort(e.render())
  }
  try
    @liberty.query_timing(
      transition,
      "C",
      "Y",
      "A",
      "rise_transition",
      0.0,
      0.0,
      policy=@liberty.Extrapolate,
    )
  catch {
    @liberty.LibertyError(code, _, _) =>
      if code != "NegativeTransition" {
        abort("wrong negative transition diagnostic")
      }
  } noraise {
    _ => abort("negative transition accepted")
  }
  println(
    "Published 0.4.4 consumer passed: shared pins, SI query, quoted logic, units, local types",
  )
}
```

机读证据位于本地 artifacts/publication-044.json；[0.4.3 记录](history/CONSUMER_0_4_3.md)原样保留。完整 Liberty 2017.06 及穷尽规则目录仍未完成，成功发布与消费者测试不替代这些目标。
