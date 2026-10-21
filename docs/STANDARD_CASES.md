# 2017.06 兼容与求值边界案例

2026-10-21 实际运行。以下输入为本项目原创结构/反例数据，Apache-2.0；不是来自手册的复制示例，也不是表征完成的工艺库，不能证明完整标准符合性。

## A：完整语句 include 与单位化查询

include-main.lib 在 cell 内引用 pins.inc；sources.json 显式提供两引脚和一个 scalar 延迟表。没有提供源映射时返回 MissingInclude；提供映射后 compat 通过当前规则，完整符合性字段仍为 false。expand 生成可单独读取的 .lib，再 lint 得到零错误，查询 INV_X1/Y、关联 A 得到 **2.5e-11 秒**。原始值为 0.025，声明单位 1ns，包含后的全局单位和原父组语义均保留。

命令从仓库根运行，expanded.lib 已存在时需显式 --force：

```powershell
moon run cmd/moon-liberty -- expand tests/fixtures/liberty2017/include-main.lib --sources tests/fixtures/liberty2017/sources.json --standard 2017.06 -o expanded.lib
moon run cmd/moon-liberty -- lint expanded.lib --json
moon run cmd/moon-liberty -- query expanded.lib --cell INV_X1 --pin Y --related A --table cell_rise --slew 1e-11 --load 1e-15 --json
```

## B：声明类型反例

declared-types-bad.lib 将一个用户属性声明为 integer，但赋值 1.5。compat 返回退出码 1、DefinedAttributeType，指出 cell 路径和位置。成功解析该文本并不让它通过已实现的类型检查。

```powershell
moon run cmd/moon-liberty -- compat tests/fixtures/liberty2017/declared-types-bad.lib --standard 2017.06 --json
```

## C：CCS/LVF、总线、时序与功耗数据可以保留

preserve-models.lib 包含 bus、bundle、ff、功耗、OCV/LVF、电流波形、三维坐标及自定义组。compat 列出 preserved_only，往返后这些字段仍在；normalize 后与原输入的结构差异为零。请求 output_current_rise 数值求值会显式拒绝，不返回 NLDM 近似数值。该测试验证格式承载和“求值范围外”的边界，不声称这个合成文件已通过全套标准 schema 或工艺约束。

## 自动复现

```powershell
moon build --release --deny-warn
python scripts/check-standard.py --executable _build/native/release/build/cmd/moon-liberty/moon-liberty.exe
```

本次 13 次 CLI 执行断言全部通过，报告为 artifacts/standard-cases.json。除上述三个场景，还验证错误 JSON 源映射、嵌套 include 拒绝、保留字段、完整符合性字段恒为 false。持续集成重复执行。
