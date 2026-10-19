# 作为独立消费者验证发布包

2026-10-19 已在独立临时项目实际执行 moon add SongYZZZ/moon-liberty，下载到 0.1.0，随后 native 严格检查、运行和 JS 严格检查通过。没有通过本地路径依赖替代公开包。

最小 moon.mod：

```moonbit
name = "example/liberty-consumer"
version = "0.1.0"
preferred_target = "native"
import { "SongYZZZ/moon-liberty@0.1.0" }
```

moon.pkg：

```moonbit
import { "SongYZZZ/moon-liberty" @liberty }
options("is-main": true)
```

main.mbt：

```moonbit
fn main {
  let expression = @liberty.parse_logic("!(A & B)") catch {
    error => abort(error.render())
  }
  let rows = @liberty.truth_table(expression) catch {
    error => abort(error.render())
  }
  if rows.length() != 4 || rows[3].output {
    abort("truth table mismatch")
  }
  let unit = @liberty.parse_unit("1ns", Time) catch {
    error => abort(error.render())
  }
  if unit != 1.0e-9 {
    abort("unit mismatch")
  }
  let root = @liberty.parse_liberty(
    "library(public_consumer){cell(INV){area:2;}}",
  ) catch {
    error => abort(error.render())
  }
  let text = @liberty.write_liberty(root) catch {
    error => abort(error.render())
  }
  let reparsed = @liberty.parse_liberty(text) catch {
    error => abort(error.render())
  }
  if reparsed.groups("cell")[0].name() != "INV" {
    abort("roundtrip mismatch")
  }
  println("Published MoonLiberty 0.1.0 consumer passed: logic, SI unit, parse/write/reparse")
}
```

运行 moon check --deny-warn、moon run .、moon check --target js --deny-warn。需要与 README 相同版本的 SDK/core。
