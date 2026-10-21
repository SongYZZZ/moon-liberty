# 0.2.0 发布包的独立消费者验证

2026-10-21 在独立目录通过精确版本依赖 SongYZZZ/moon-liberty@0.2.0 从 Mooncakes 下载，严格 native 检查、实际运行及 JS 严格检查均通过。没有使用本地路径依赖替代公开包。测试显式标准选择、include 展开、完整符合性 false 的报告，以及 2.5e-11 秒 SI 查询。

实际运行的 main.mbt 如下；moon.pkg 使用 @liberty 别名并设置 is-main，moon.mod 声明上述 0.2.0 依赖和 preferred_target native。

```moonbit
///|
fn main {
  let standard = @liberty.parse_standard("2017.06") catch {
    error => abort(error.render())
  }
  let input = "library(x){time_unit:\"1ns\";capacitive_load_unit(1,pf);cell(INV){include_file(pins);}}"
  let sources = Map([("pins", "pin(A){direction:input;}pin(Y){direction:output;function:\"!A\";timing(){related_pin:\"A\";cell_rise(scalar){values(\"0.025\");}}}")])
  let root = @liberty.parse_liberty_sources(input, sources) catch {
    error => abort(error.render())
  }
  let report = @liberty.compatibility_report(root, standard~) catch {
    error => abort(error.render())
  }
  if report.complete_conformance || !report.roundtrip_verified ||
    report.findings.any(f => f.severity is Error) {
    abort("format result mismatch")
  }
  let model = @liberty.build_library(root) catch {
    error => abort(error.render())
  }
  let query = @liberty.query_timing(model, "INV", "Y", "A", "cell_rise", 1.0e-11, 1.0e-15) catch {
    error => abort(error.render())
  }
  if (query.seconds - 2.5e-11).abs() > 1.0e-23 { abort("SI result mismatch") }
  println("Published 0.2.0 consumer passed: 2017.06, include, report and SI query")
}

```

验证命令：moon check --deny-warn、moon run .、moon check --target js --deny-warn。运行结果为 Published 0.2.0 consumer passed: 2017.06, include, report and SI query。旧版记录保留在 history/CONSUMER_0_1.md。
