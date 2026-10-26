# 0.4.1 发布包的独立消费者验证

2026-10-26，moon publish 返回 200 OK。发布源码基准为 41a4bd5c7c4f6e43d12892695a4c72a113e7e037，归档 SHA-256：c4023740609bb12c30ae7c3d8e66da9fc7ca7c7bbc606460bfbfaba532daffd8。

从独立目录精确下载 SongYZZZ/moon-liberty@0.4.1，未使用本地路径。native 严格检查及实际运行、JS/Wasm GC 严格检查全部通过。49 个 .mbt 和根 moon.mod/moon.pkg 与发布源码逐字节一致；归档不含依赖缓存、构建、下载工具或 artifacts。

保留 0.4.0 的公共 API 消费代码，并额外确认缺轴具名表返回 TableShape、合法 SR 锁存器不被误拒绝。实际主程序：

```moonbit
fn main {
  let input = "library(x){time_unit:\"1ns\";capacitive_load_unit(1,pf);cell(C){pin(A,B){direction:input;}pin(Y,Z){direction:output;function:\"A & B\";timing(){related_pin:\"A B\";cell_rise(scalar){values(\"0.03\");}}}}}"
  let library = @liberty.load_library(input, model_limits={ max_pins: 100, max_work: 1000 }) catch { e => abort(e.render()) }
  if library.inventory().pins != 4 { abort("shared pin expansion failed") }
  let answer = @liberty.query_timing(library, "C", "Z", "B", "cell_rise", 0.0, 0.0) catch { e => abort(e.render()) }
  if (answer.seconds - 3.0e-11).abs() > 1.0e-23 { abort("alias SI query failed") }
  let report = @liberty.compatibility_report(library.source) catch { e => abort(e.render()) }
  if report.complete_conformance { abort("incomplete standard claimed complete") }
  let expression = @liberty.parse_logic("\"0\"") catch { e => abort(e.render()) }
  let formatted = @liberty.format_logic(expression) catch { e => abort(e.render()) }
  let reparsed = @liberty.parse_logic(formatted) catch { e => abort(e.render()) }
  if expression != reparsed { abort("quoted signal identity lost") }
  @liberty.validate_units({ time_seconds: 1.0e-9, capacitance_farads: 1.0e-12, voltage_volts: None }) catch { e => abort(e.render()) }
  let root = @liberty.parse_liberty("library(x){cell(C){type(W){bit_width:1;}bus(D){bus_type:W;pin(D[0]){}}}}") catch { e => abort(e.render()) }
  if @liberty.standard_findings(root).any(f => f.severity == @liberty.Error) { abort("local type rejected") }
  let invalid = @liberty.parse_liberty("library(x){lu_table_template(T){}cell_rise(T){values(\"1\");}}") catch { e => abort(e.render()) }
  try @liberty.read_table(invalid.groups("cell_rise")[0], template=invalid.groups("lu_table_template")[0]) catch {
    @liberty.LibertyError(code, _, _) => if code != "TableShape" { abort("wrong missing-axis diagnostic") }
  } noraise { _ => abort("missing axes accepted as scalar") }
  let sr = @liberty.parse_liberty("library(x){cell(C){latch(Q,QN){clear:\"0\";preset:\"1\";clear_preset_var1:L;}}}") catch { e => abort(e.render()) }
  if @liberty.standard_findings(sr).any(f => f.severity == @liberty.Error) { abort("SR latch incorrectly rejected") }
  println("Published 0.4.1 consumer passed: shared pins, SI query, quoted logic, units, local types")
}
```

验证命令：moon update、moon check --deny-warn、moon run .、moon check --target js --deny-warn、moon check --target wasm-gc --deny-warn。历史记录保留在 history/CONSUMER_0_4.md。接口兼容与消费验证不等同于完整标准兼容。
