# Liberty 2017.06 标准兼容契约

更新时间：2026-10-21。此文件回应初审意见，并固定“兼容做到哪里算完成”的终点。

## 1. 唯一基线与版本来源

基线是 Synopsys《Liberty User Guides and Reference Manual Suite》，**Version 2017.06（June 2017）**，包括该套件的 Release Notes、User Guide Vol. 1/2 和 Reference Manual。它是固定版本的格式文档，不是本项目自创的“Liberty 子集”，也不称为 IEEE 编号标准或最新版本。

官方获取入口为 [Synopsys TAP-in / Liberty](https://www.synopsys.com/community/interoperability-programs/tap-in.html)，需遵守其下载授权；核对版本时查阅了带 Synopsys 署名的[2017.06 套件公开镜像](https://manuals.plus/m/c06ac2f60609fe732b62ee745595b383be0db873dfee9ab41fc17d3e027c4de1.pdf)。仓库只保留来源链接、自编实现、规则摘要和原创测试，不分发手册、其大段正文或厂商代码。手册的授权不由本仓库 Apache-2.0 替代。

2017.06 的发布说明包含 LVF 更新，因而“完整格式兼容”不能排除 LVF、CCS 或仅保留 NLDM。所选版本的这些数据始终属于读取、结构验证和写回的最终目标；是否执行其物理模型计算是另一件事。

## 2. 最终完整格式兼容目标（v1.0 验收契约）

最终目标是：**在公开声明的资源上限内，完整承载 2017.06 的合法语法、所有标准分组/属性及其结构数据；覆盖该版本规定的格式层约束，通过正例、反例与跨工具往返，不静默删除不参与求值的数据。**具体完成判据：

1. 词法与语法：覆盖该版本规定的标识符、数值/字符串、注释/续行、simple/complex attribute 和嵌套 group，以及完整语句边界上的 include_file。资源限制作为单独错误，不伪称格式不合法。
2. 结构与数据：全部标准分组和属性都能进入通用 AST 并原义写回，包括 bus/bundle、时序与状态表、功耗、噪声、电流波形、变化模型及所选版本规定的其他族。注释与原排版不属于语义等价要求。
3. 格式层语义：逐条落实该版本规定的参数、属性类型、允许父组/作用域、模板和其他名称引用。通用 AST 接受一个名字，不能替代这一项验证。
4. 文档条目闭环：Reference Manual 的每个分组/属性条目均须映射到实现或原样承载规则、正例/反例/引用检查及状态。当前家族矩阵只是导航，不能把有限类别的通过率称为全手册覆盖率。
5. 互操作：按标准案例和有权再分发的真实库完成“读入→展开→写出→独立工具读入”语义核对，并验证未知扩展未丢失；不能只依赖一个 PDK 样本。
6. 标准外扩展：与基线分开登记。define / define_group 的合法扩展可保留和校验；未分类字段保留并报告，不自动称为该版本标准条目。
7. 完成标志：只有逐条清单、负例和互操作证据闭环，才能把完整符合性标为完成。不会因为 lint 零错误、格式化成功或没有 NLDM 求值请求，就宣告全标准通过。

**当前 0.2.0 尚未完成第 3—5 项的全部条目，完整标准符合性明确为 false。**这是一项目标清晰、可分阶段验收的标准实现；本轮不以“已完全符合 2017.06”作为申报事实。

## 3. 格式兼容与受限求值的关系

| 层次 | 最终范围 | 0.2.0 当前事实 |
| --- | --- | --- |
| 通用读写 | 全部 2017.06 格式结构、内容及合法扩展 | 通用 AST、确定性写出及结构往返；完整逐条符合性仍开放 |
| 标准结构检查 | 完整版本的格式层参数/类型/作用域/引用规则 | include 边界、define/define_group 及既有单元/引脚/NLDM 规则；其余见矩阵 |
| 数值求值 | 明确限定，不因格式目标扩大而无限扩张 | 标量/一维/二维 NLDM，四类组合表的 SI 查询；约束表可通过库 API 查表 |
| 波形/统计/系统 | 不属于当前求值器 | CCS/ECSM/LVF 数据、状态和功耗结构保留；不执行波形、统计分析或路径 STA |

“完整格式”不等于“实现 Synopsys 全套计算工具”；反过来，“只求值 NLDM”也不能成为丢弃其他格式数据或回避其格式规则的理由。读取并保留 LVF 数据与计算统计分布是两个不同验收点。

## 4. 用户如何核对当前状态

```powershell
moon run cmd/moon-liberty -- compat tests/fixtures/liberty2017/preserve-models.lib --standard 2017.06 --json
moon run cmd/moon-liberty -- compat tests/fixtures/liberty2017/include-main.lib --sources tests/fixtures/liberty2017/sources.json --standard 2017.06 --json
moon run cmd/moon-liberty -- expand tests/fixtures/liberty2017/include-main.lib --sources tests/fixtures/liberty2017/sources.json --standard 2017.06 -o expanded.lib
```

--standard 是调用者选择的解释目标，不是根据 date 字段自动检测的版本。当前 compat 返回：

- target_standard：Liberty 2017.06。
- implemented_checks_passed：是否通过已实现的规则。
- roundtrip_verified：当前输入结构是否经过写出及重解析核对。
- complete_standard_conformance：当前为 false，与前两项独立。
- features：哪些数据族出现，以及 eligible_after_query_checks、table_lookup_only、preserved_only 等求值状态；未分类组单独警告。
- findings：错误码、严重级别、结构路径和位置。

退出 0 表示已实现的检查通过，不表示完整符合；1 表示已实现规则发现错误；2 表示解析、版本、include 解析或 IO 等失败。expand 是结构操作，不替代 compat/lint。

## 5. include 的可复现输入与约束

纯核心 parse_liberty_sources(text, Map[String,String]) 接受显式文件名到源码文本的映射。CLI 用 --sources JSON 提供相同映射，不隐式访问当前目录或搜索路径。调用方可自行实现受控文件读取后传入映射，这属于 IO 适配，不改变片段语法。

included fragment 必须包含完整语句、保持组边界、只指定一个叶文件名；按 2017.06 的规则，已包含文件中不得再出现 include_file。父级与所有片段共用字符/token/节点/深度预算，重复使用片段也计入预算。缺失源、路径形式文件名、嵌套引用和坏片段会显式失败，不以空内容替代。

## 6. 分阶段验证入口

[机器可读家族矩阵](standards/liberty-2017.06.json)列出当前状态、开放项和测试证据；[案例说明](STANDARD_CASES.md)给出 13 次 CLI 断言。完整字段级 schema、更多合法真实语料及全部负例闭环属于 v1.0 前必须完成的格式工作，不能以增加无关功能替代。
