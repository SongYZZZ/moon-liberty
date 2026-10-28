# MoonLiberty 0.4.2 保守复查（2026-10-28）

## 总体判断

优先复核现有项目完整性、错误处理和材料一致性，修补四处实际复现的缺陷，并按追加要求增加一项小范围输入兼容。九个命令、六份公开接口和物理求值范围保持一致，未增加依赖。完整 Liberty 2017.06 标准兼容仍未完成，不能据此判定官方终审通过。上一轮记录见 [0.4.1 报告](history/FINAL_REVIEW_0_4_1.md)。

## 已复现并修复

1. 裸值紧邻反斜杠续行时，旧版把反斜杠读进 area 值并报 InvalidNumber。现在 LF/CRLF 都由既有续行流程处理；孤立 CR 仍拒绝，行列位置保留。依据 UG1 1-3 的 Statements 规则。
2. 行/块注释可绕过 NUL 拒绝。现在扫描前统一拒绝，返回 InvalidCharacter 和实际位置；文件命令失败后没有输出文件。
3. statetable 内部节点在 compat 已能识别，lint 却报 UnknownSignal。现在补入同一 cell 的函数和 when 引用环境；未知名称和跨 cell 引用仍报错，内部节点不会变成 related_pin。依据 UG1 5-26、Reference 2-118；没有实现状态仿真。
4. values(-1e308,0)、轴 [0,1]、外推坐标 2 的真实结果为有限 1e308，旧实现中间乘法先溢出而拒绝。现在只在该异常算术分支缩放计算；不可表示结果仍报 NumericRange，正反方向和二维路径都有回归。

## 有限兼容增量

根文件及显式 include 片段允许开头有一个 U+FEFF（UTF-8 编码签名）。旧版 BOM 文件报 InvalidRoot，本版可检查、规范化及比较。BOM 计入输入预算和原始 offset，跳过时不占可见列；中途或重复的 U+FEFF 不当作空白删除，引号内容保留；写出为普通 UTF-8。这是输入编码适配，不列为新增标准条目，参见 [Unicode BOM 说明](https://www.unicode.org/faq/utf_bom.html)。

## 验证与材料

- SDK/core 0.10.14+7d59c7ec9；fmt/check --deny-warn、info、release 构建与两个实际例子通过。上游 async 在 Windows C 编译中仍可能出现 EINVAL 宏重定义警告，未修改依赖或掩盖此提示。
- 348 native；核心 JS/Wasm GC 各 323。新增 11 项回归，其中八项缺陷回归先在旧实现上失败；不按后端重复累计为不同测试。
- CLI 27 次、标准 CLI 29 次、不变量流程 66 次；后者含 55 次 Decimal 合成对照。IHP 312 次、Nangate 72 次真实库数值核对，以及结构往返/提取通过。ASAP7 原始缺分号输入继续作为拒绝负例。
- 六份生成接口与 0.4.1 的 SHA-256 相同。原始复现和修复后 CLI 结果、本轮机器记录在本地 artifacts/audit-042.json；临时样本位于 D:/Dev/Temp/moon-liberty-audit-20261028。
- 正式材料仍仅根 PROJECT_APPLICATION.md，名称、仓库、版本、测试数据与实际项目一致；修正文档中旧的 25 次检查、反例类别数与 compat 退出码遗漏。当前相对链接检查通过。
- 官方十月公开源码重新读取：最多三人、十月最多提交三次，截止 2026-10-31。飞书完整章程仍不可访问，未宣称已逐条核对该内容，见 [赛事材料核对](CONTEST_REQUIREMENTS.md)。

已使用安装的 osc2026-guide 工程审查项，同时独立复核源代码、[2017.06 原厂手册镜像](https://manuals.plus/m/c06ac2f60609fe732b62ee745595b383be0db873dfee9ab41fc17d3e027c4de1.pdf)、真实库及数值结果。没有把技能的 OSC/八月规则当作十月章程。

## 保留的实质缺口

全手册字段级 schema、完整引用/父组/词法规则、特殊根结构、完整 CCS/ECSM/LVF/噪声等格式规则尚须闭环；最终完整目标与 false 标记继续见 [标准契约](STANDARD_CONFORMANCE.md)。本轮未扩张三维、波形、统计或向量求值。测试和 CI 通过不是完整标准认证，也不保证官方审核结果。

发布包、独立消费者及远程 CI 的最终记录见 [消费者验证](CONSUMER.md)；只在实际完成后补记对应版本证据。不发送邮件、群消息或代填报名表。
