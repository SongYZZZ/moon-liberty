# 0.3.0 发布包的独立消费者验证

2026-10-25，moon publish 返回 Server status: 200 OK；发布源码基准为 672818f0b9fc4a23db886132245502738566aa6e。归档 SHA-256：cdd40bfde51d284a48987696ba361e6ea3b4a4139fed670a108daa0039bc8e20。

在独立目录声明 SongYZZZ/moon-liberty@0.3.0 的精确注册表依赖，moon update 实际下载该版本，未使用本地路径。严格 native 检查及实际运行、JS/Wasm GC 严格检查均通过。下载包中全部 47 个 MoonBit 文件与本轮源码逐字节一致；不是只核对版本号。

消费者验证完整符合性仍为 false、18 族规则目录、XOR 优先于 AND 和三维格式 API。实际 main.mbt 如下；moon.pkg 使用 @liberty 别名并设置 is-main，moon.mod 设置 preferred_target native。

```moonbit
fn main {
  let root = @liberty.parse_liberty("library(x){cell(C){pin(A){direction:input;}}}") catch { e => abort(e.render()) }
  let report = @liberty.compatibility_report(root) catch { e => abort(e.render()) }
  assert_false(report.complete_conformance) catch { e => abort(e.to_string()) }
  assert_eq(@liberty.standard_rule_ids().length(), 18) catch { e => abort(e.to_string()) }
  let expression = @liberty.parse_logic("A & B ^ C") catch { e => abort(e.render()) }
  assert_eq(expression, @liberty.And(@liberty.Signal("A"), @liberty.Xor(@liberty.Signal("B"), @liberty.Signal("C")))) catch { e => abort(e.to_string()) }
  let tables = @liberty.parse_liberty("library(x){lu_table_template(T){index_1(\"1,2\");index_2(\"3\");index_3(\"4,5\");}cell_rise(T){values(\"1,2\",\"3,4\");}}") catch { e => abort(e.render()) }
  let data = @liberty.read_table_data(tables.groups("cell_rise")[0], template=tables.groups("lu_table_template")[0]) catch { e => abort(e.render()) }
  assert_eq(data.axes.length(), 3) catch { e => abort(e.to_string()) }
  println("Published 0.3.0 consumer passed: report, rules, Liberty precedence, 3D format")
}
```

命令：moon update、moon check --deny-warn、moon run .、moon check --target js --deny-warn、moon check --target wasm-gc --deny-warn。输出：Published 0.3.0 consumer passed: report, rules, Liberty precedence, 3D format。

历史消费者记录分别保留在 history/CONSUMER_0_2.md、history/CONSUMER_0_1.md。发布包通过消费验证，不改变完整标准仍未完成的结论。
