# 2017.06 兼容与求值边界案例

2026-10-26 按 0.4.0 重新实际运行。以下输入为本项目原创结构/反例数据，Apache-2.0；不是来自手册的复制示例，也不是表征完成的工艺库，不能证明完整标准符合性。

## A：完整语句 include 与单位化查询

include-main.lib 在 cell 内引用 pins.inc；sources.json 显式提供两引脚和一个 scalar 延迟表。没有提供源映射时返回 MissingInclude；提供映射后 compat 通过当前规则，完整符合性字段仍为 false。expand 生成可单独读取的 .lib，再 lint 得到零错误，查询 INV_X1/Y、关联 A 得到 **2.5e-11 秒**。原始值为 0.025，声明单位 1ns，包含后的全局单位和原父组语义均保留。

命令从仓库根运行，expanded.lib 已存在时需显式 --force：

```powershell
moon run cmd/moon-liberty -- expand tests/fixtures/liberty2017/include-main.lib --sources tests/fixtures/liberty2017/sources.json --standard 2017.06 -o expanded.lib
moon run cmd/moon-liberty -- compat expanded.lib --standard 2017.06 --json
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

场景 C 的独立命令（前三步预期退出 0，最后一步预期退出 2 并给出不支持的查询错误）：

```powershell
moon run cmd/moon-liberty -- normalize tests/fixtures/liberty2017/preserve-models.lib -o models-normalized.lib
moon run cmd/moon-liberty -- diff tests/fixtures/liberty2017/preserve-models.lib models-normalized.lib --json
moon run cmd/moon-liberty -- extract tests/fixtures/liberty2017/preserve-models.lib --cells DFF_BUS -o models-selected.lib --json
moon run cmd/moon-liberty -- query tests/fixtures/liberty2017/preserve-models.lib --cell DFF_BUS --pin Q --related CK --table output_current_rise --slew 1e-11 --load 1e-15 --json
```

提取保留指定单元及库级 type、模板与扩展声明；这些结构处理不代表全部格式语义已通过。上面输出已存在时显式添加 --force。场景 A 的兼容、lint、查询预期均退出 0，场景 B 预期退出 1。

```powershell
moon build --release --deny-warn
python scripts/check-standard.py --executable _build/native/release/build/cmd/moon-liberty/moon-liberty.exe
```

本次自动脚本 25 次 CLI 执行断言全部通过，报告为 artifacts/standard-cases.json。除上述三个场景，还验证错误 JSON 源映射、嵌套 include 拒绝、保留字段、完整符合性字段恒为 false，以及总线、状态表、LVF/模板、负转换时间等八类格式反例。持续集成重复执行。

## D：共享标量引脚与新增不变量

shared-pins.lib 使用 pin(A,B)、pin(Y,Z)。inspect 得到 4 个直接标量引脚；lint 零错误；查询 AND2_DUAL/Z、关联 B 的 cell_rise 得到 3e-11 秒。标准脚本还验证缺少 next_state 的 ff 被拒绝。额外脚本 audit-invariants.py 固定种子 20261026，用 100 位 Decimal 核对 52 次插值，并测试引号信号差异、提取、局部 type 和缺失状态方程，共 61 次 CLI 调用。所有合成数据均为原创测试，不冒充 PDK。
