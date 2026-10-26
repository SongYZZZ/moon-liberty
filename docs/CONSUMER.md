# 0.4.0 发布包的独立消费者验证

2026-10-26，moon publish 返回 200 OK。发布源码基准为 753049c93f5548e141d195d4740d85c9849f63b1，归档 SHA-256：38b30de29ecd7e7af0f481b7a88b4fe34aed0cd921845ddfb2002c93aa122e25。

独立目录精确依赖 SongYZZZ/moon-liberty@0.4.0，moon update 实际从注册表下载，无本地路径替代。严格 native 检查与运行、JS/Wasm GC 严格检查均成功。下载包全部 49 个 .mbt 及根 moon.mod/moon.pkg 与本轮源码逐字节一致；压缩包没有 .tools、构建、缓存或 artifacts 目录。

消费者验证多名称引脚展开、别名 SI 查询、引号信号往返、公开单位校验、单元局部 type 和完整符合性为 false。实际主程序：

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
  println("Published 0.4.0 consumer passed: shared pins, SI query, quoted logic, units, local types")
}
```

moon.mod 的精确版本依赖为 SongYZZZ/moon-liberty@0.4.0；moon.pkg 导入别名 @liberty 并设置 is-main。运行 moon update、moon check --deny-warn、moon run .、moon check --target js --deny-warn、moon check --target wasm-gc --deny-warn，输出 Published 0.4.0 consumer passed: shared pins, SI query, quoted logic, units, local types。

历史 0.3.0 记录在 history/CONSUMER_0_3.md。消费验证不是完整标准符合性证明。
