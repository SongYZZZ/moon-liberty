# 多来源互操作证据

2026-10-25，所有下载地址固定到提交，SHA-256 与授权文本列于 [corpus.json](standards/corpus.json)。下载文件只进入被忽略的 .tools/corpus；不把外部数据规模算作 MoonBit 实现。IHP 原有样本与测试流程另见 TESTING、REFERENCES。

| 原始输入 | 分类与实测结果 |
| --- | --- |
| Nangate Open Cell Library typical | OpenROAD 所分发的研究用库，135 单元、541 个直接引脚、1478 弧、4845 个六类 NLDM 表；lint/已实现 compat 规则零错误，独立完整结构往返一致；四个单元共 72 次数值核对通过 |
| Yosys busdef.lib | 上游合成回归样本，不冒充真实工艺库；bus/type 与 SRAM 结构可保留和独立往返；memory 组未分类警告保留 |
| Yosys dff.lib | 上游合成回归样本；未加引号的括号 clocked_on 表达式可检查和往返；缺少 SI 单位仅在 lint 提醒，不能执行 SI 查询 |
| ASAP7 INVBUF / SEQ 原文件 | 原始文件有 area 后缺少分号，严格语法明确返回 MissingSemicolon；未补分号、未把这两份计为成功解析的真实库 |

独立读取器为 Thomas Kramer 的 [liberty-parser](https://codeberg.org/tok/liberty-parser) 0.0.29，GPL-3.0-or-later；由固定版本依赖安装在 .tools/corpus-oracle，不进入 MoonBit 运行时或发布源码。它与 IHP 原有 GPL-2.0 对照工具是两套读取器。适配脚本只取其公开 AST，数值预期由独立读取的轴与数据四角加权计算。

完整结构比较包含组顺序/参数、全部属性（包括重复属性）与 define 声明；仅将读取器保留的反斜杠换行续行消除后比较，不要求排版字节一致。没有跳过不参与求值的组。Nangate 的 ns/ff 单位与原 IHP ns/pf 样本不同，可验证容量换算。

复现：

```powershell
python scripts/fetch-corpus.py
python -m pip install --target .tools/corpus-oracle -r scripts/corpus-oracle-requirements.txt
python scripts/corpus_check.py --executable _build/native/release/build/cmd/moon-liberty/moon-liberty.exe
```

报告 artifacts/corpus/report.json 含 89 次 CLI 调用（72 次查询已包含其中，不能相加重复计数）。IHP 另有 312 次查询，两来源数值核对共 384 次。ASAP7 拒绝是严格分号语法下的负例，不推断其他 EDA 工具一定拒绝这些方言。样本互操作不能替代全版本规则目录、完整标准符合性或工艺签核。
