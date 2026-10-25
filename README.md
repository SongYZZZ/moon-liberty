# MoonLiberty

**MoonLiberty：芯片标准单元库的 Liberty 解析、NLDM 时序查询与变更审计工具。**

[GitHub 仓库](https://github.com/SongYZZZ/moon-liberty) · [正式项目申报书](PROJECT_APPLICATION.md) · [范围与限制](docs/SUPPORT.md) · [验证记录](docs/TESTING.md) · [生态检索](docs/ECOSYSTEM_REVIEW.md)

**标准基线固定为 Synopsys Liberty 2017.06。**最终目标是该版本完整格式读写与格式层规则闭环；当前 0.3.0 仍为部分实现，完整符合性明确标为 false。[标准兼容契约](docs/STANDARD_CONFORMANCE.md)说明终点、缺口及与受限求值的关系，[复审说明](docs/RESUBMISSION_RESPONSE.md)说明本轮改动。

原创 MoonBit 基础库与原生命令行，面向 PDK 维护者、EDA 工具作者和数字电路教学。将文本库转成可检查的结构，按明确的物理单位查询延迟，并在库升级时指出具体字段、逻辑函数或时序表变化。实现使用 Apache-2.0；作者为宋永振（SongYZZZ）。

## 可以实际完成的工作

- 带行列位置和资源上限的 Liberty 词法、分组及属性解析，保留未知厂商属性和分组，确定性写出。
- 单元、引脚、时序弧和模板建模；检查重复名称、无效数值、引脚引用、函数引用及表格形状。
- 标量、一维和二维 NLDM 表校验及插值；组合弧查询把秒、法拉映射到声明的库单位，结果输出秒。
- 布尔函数解析、求值和有输入数上限的真值表。
- 按结构路径比较库：忽略注释、属性顺序及部分等价数值写法，保留未知字段的差异；选择单元时保留所有库级上下文。
- 显式标准版本 compat 报告、受控 include 展开、扩展声明及 18 族可追溯结构规则；包括总线、状态表、模板、三维表格和 30 种 2017.06 LVF 矩表的格式检查。
- 九个原生命令、JSON 输出及明确退出码；写文件默认拒绝覆盖，失败时不发布部分结果。

本工具不是完整 STA、工艺签核或电气等价证明系统；格式化成功也不代表语义无误。CCS/ECSM/LVF、三维查表、总线展开等不在当前求值范围内，详见[支持矩阵](docs/SUPPORT.md)。

## 快速运行

使用 MoonBit SDK **0.10.14+7d59c7ec9** 和对应 core（CI 固定版本），原生后端需 C 工具链。所有命令从本仓库根目录运行：

```powershell
moon update
moon test --target native --deny-warn
moon build --release --deny-warn
moon run cmd/moon-liberty -- inspect tests/fixtures/ihp-sg13g2-typ.lib --json
moon run cmd/moon-liberty -- lint tests/fixtures/ihp-sg13g2-typ.lib --json
moon run cmd/moon-liberty -- query tests/fixtures/ihp-sg13g2-typ.lib --cell sg13g2_inv_1 --pin Y --related A --table cell_rise --slew 1e-10 --load 2e-14 --json
```

公开 IHP SG13G2 样本的实际结果为 **84 单元、285 引脚、384 时序弧、1199 表格**，当前规则下 lint 为 0 错误、0 警告。上面的查询得到约 **1.1540884836886307e-10 秒**，未钳位、未外推。这个结果只表示该表的插值结果。

格式化、比较、提取与布尔函数：

```powershell
moon run cmd/moon-liberty -- normalize tests/fixtures/basic.lib -o normalized.lib
moon run cmd/moon-liberty -- diff tests/fixtures/basic.lib normalized.lib --json
moon run cmd/moon-liberty -- extract tests/fixtures/ihp-sg13g2-typ.lib --cells sg13g2_inv_1 -o inv.lib
moon run cmd/moon-liberty -- truth "!(A & B)" --json
```

已有输出需显式传入 --force。命令行退出码：0 为成功或无差异，1 为 lint 错误或发现差异，2 为参数、解析、查询或文件错误。可执行文件位于 _build/native/release/build/cmd/moon-liberty/moon-liberty.exe；Linux 的此版本 MoonBit 也使用 .exe 文件名。

## 用作 MoonBit 库

项目名为 SongYZZZ/moon-liberty；0.3.0 已发布至 Mooncakes，可用 moon add SongYZZZ/moon-liberty 添加，也可通过本仓库查看实现。moon.pkg 显式设置易读的包别名：

```moonbit
import {
  "SongYZZZ/moon-liberty" @liberty,
}
```

新增标准命令（其他命令见原有示例）：

    moon run cmd/moon-liberty -- compat tests/fixtures/liberty2017/preserve-models.lib --standard 2017.06 --json
    moon run cmd/moon-liberty -- expand tests/fixtures/liberty2017/include-main.lib --sources tests/fixtures/liberty2017/sources.json --standard 2017.06 -o expanded.lib

[三个标准案例](docs/STANDARD_CASES.md)附有 21 次 CLI 执行断言。格式完整兼容的目标包含 CCS/LVF、总线、状态和功耗结构；当前对这些数据保留、审计并明确不求值。

主要 API：

| 入口 | 用途 |
| --- | --- |
| parse_standard / compatibility_report | 显式版本与已实现格式规则报告 |
| parse_fragment / parse_liberty_sources | 完整语句片段与有界 include 展开 |
| tokenize / parse_liberty / write_liberty | 词法、通用 AST、保留扩展的写出 |
| load_library / lint_library | 建模与结构、引用及表格检查 |
| read_units / parse_unit | 声明单位解析，不猜测缺失单位 |
| standard_findings / standard_rule_ids | 已实现标准结构检查及规则目录 |
| read_table_data / validate_table_data | 标量至三维格式读取和形状校验，不执行三维插值 |
| validate_table / lookup_table | 校验和标量、一维、二维插值 |
| query_timing | 组合弧的秒/法拉输入和秒输出 |
| parse_logic / evaluate_logic / truth_table | 布尔函数和有界真值表 |
| compare_libraries / select_cells | 变更审计与上下文保留的单元提取 |

库函数使用 LibertyError 报错，包含错误码、消息和位置；lint 返回含严重级别、结构路径和位置的 Finding。CLI 的异步 IO 与纯计算核心分包，核心无运行时领域依赖，可在 native、JS、Wasm GC 使用。[设计及数据契约](docs/DESIGN.md)说明返回值、单位、选择条件和差异含义。

## 验证与独立核对

原生 **305 项测试**通过；纯核心 **281 项测试**分别在 JS、Wasm GC 通过。另有 18 次原 CLI、21 次标准 CLI 检查；新增语料流程有 89 次 CLI 调用，其中 72 次为 Nangate 四个单元上的独立数值核对。使用独立 Python Liberty 解析器对真实库核对结构清单、完整往返、单元提取，并核对 **IHP 12 个单元上的 312 次时序数值查询**，另加 Nangate 72 次，共 384 次。独立工具仅作为可选测试过程，未复制进 MoonBit 实现或运行时依赖。

```powershell
moon test --target js -p SongYZZZ/moon-liberty --deny-warn
moon test --target wasm-gc -p SongYZZZ/moon-liberty --deny-warn
python scripts/verify.py --executable _build/native/release/build/cmd/moon-liberty/moon-liberty.exe --identity
pwsh scripts/fetch-oracle.ps1
python scripts/oracle_check.py --executable _build/native/release/build/cmd/moon-liberty/moon-liberty.exe
python scripts/fetch-corpus.py
python -m pip install --target .tools/corpus-oracle -r scripts/corpus-oracle-requirements.txt
python scripts/corpus_check.py --executable _build/native/release/build/cmd/moon-liberty/moon-liberty.exe
moon bench --target native -p SongYZZZ/moon-liberty/benchmarks
```

原 IHP oracle 获取脚本需要 gh 及 GitHub API 认证；其核对脚本只用 Python 标准库。新增多来源核对使用另一份独立 GPL-3.0-or-later 读取器，依赖只安装到忽略的 .tools/corpus-oracle。测试工具版本、许可证、命令、实测性能和限制见[验证记录](docs/TESTING.md)与[来源说明](docs/REFERENCES.md)。仓库 CI 会重复严格编译、三后端测试、CLI 验收与独立核对。

## 贡献与问题反馈

请提供 SDK 版本、最小可公开的 .lib 样本、实际命令和诊断；敏感工艺数据请先脱敏。行为修复应有针对性回归用例。运行 moon fmt、moon check --deny-warn 和相关测试后提交，范围扩展需同步支持矩阵。

测试数据来自 Apache-2.0 的 IHP Open PDK，原始头部、固定版本和 SHA-256 均保留。它不是本项目移植来源，也不能证明工艺资格或完整标准符合性。详见 [NOTICE](NOTICE) 和 [LICENSE](LICENSE)。

[发布消费者验证](docs/CONSUMER.md) · [完整自查报告](docs/FINAL_REVIEW.md)
