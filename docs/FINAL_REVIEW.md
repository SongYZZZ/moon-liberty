# MoonLiberty 0.4.1 保守复查（2026-10-26）

## 结论与范围

按本轮“优先完整性、减少新功能和新错误”的要求，检查了已有读取、建模、查询、差异、参数、写出、标准检查和测试路径。补丁集中修复已复现的边界问题，并补少量手册明确的 latch 格式规则。公开命令仍为九个，六份生成接口与 0.4.0 一致，求值范围保持不变。完整 2017.06 兼容仍未完成，不能判定官方终审通过。

## 发现与修复

1. **缺轴表错误返回常数。**原版对 lu_table_template(T){} 或 index_1() 可在 SI query 中返回标量值，绕过预期坐标检查。现在 read_table 复用 read_table_data 的格式校验；具名表必须有非空轴，声明的变量须解析到对应轴，错误返回 TableShape/InvalidLibrary。保持合法 scalar 和局部覆盖行为。
2. **整数选项接受舍入后的伪整数。**1.00000000000000001 经 Double 舍入被接受。现在先检查十进制整数字面量（可选前导 +），再检查范围；拒绝小数与指数写法。帮助中缺失 expand 的输出参数提示一并修正。
3. **latch 字段依赖缺失。**按 Reference 2-86—2-89，补 data_in/enable 配对、enable_also 依赖、clear/preset 与组合状态值相互依赖，及 L/H/N/T/X 枚举。合法 SR 锁存器仍可不带 data_in/enable，不作一概必填处理。向量/状态仿真仍不求值。

主实现较 0.4.0 净减少 42 行，新增 8 项有针对性的回归；没有新增公共 API、命令、依赖或计算模型。原始缺陷已先用 release CLI 复现，再修复验证。

## 已验证证据

- SDK/core 0.10.14+7d59c7ec9；fmt/check --deny-warn、info 和 release 构建。
- 337 native、核心 JS/Wasm GC 各 312；不按三个后端重复累计不同测试数。
- 原 CLI 20 次、标准 CLI 29 次、不变量 61 次；后者含 52 次 Decimal 合成数值对照。
- IHP 312 次、Nangate 72 次实库核对及结构往返/提取；Yosys 固定样本往返；ASAP7 原始缺分号负例保留。
- 六份生成接口与补丁前逐字比较相同；机器记录在 artifacts/api-041.json。
- 唯一正式申报书 PROJECT_APPLICATION.md、README、moon.mod 与 Git origin 的项目身份一致。全部历史、源码、环境原位保留。

相关实现与回归：table.mbt、table_data.mbt、query_test.mbt、table_data_test.mbt、cli/arguments.mbt 及测试、standard_rules.mbt 及测试、scripts/verify.py、scripts/check-standard.py。原全量工程检查记录保留在 [0.4.0 报告](history/FINAL_REVIEW_0_4.md)。

## 未完成项与保守选择

未在这次补丁中扩张 CCS/LVF 计算、完整向量展开或 phys_library，也没有将全手册字段级 schema 宣称完成。完整标准目标及具体开放项继续见 STANDARD_CONFORMANCE.md 和 standards/liberty-2017.06.json。减少已知错误不等于证明不存在其他错误，也不能以测试数代替完整标准验收。

本轮执行已安装赛事技能的工程检查项，并独立核对 [Synopsys 2017.06 手册](https://manuals.plus/m/c06ac2f60609fe732b62ee745595b383be0db873dfee9ab41fc17d3e027c4de1.pdf)与实际 CLI。技能中 OSC/八月章程不被当作十月章程。仅更新代码和仓库材料，不发送邮件、群消息或代填报名表。

## 发布与远程证据

发布源码基准 41a4bd5c7c4f6e43d12892695a4c72a113e7e037 的[完整远程 CI](https://github.com/SongYZZZ/moon-liberty/actions/runs/40336131351)已通过。0.4.1 已发布，服务器返回 200 OK；归档 SHA-256：c4023740609bb12c30ae7c3d8e66da9fc7ca7c7bbc606460bfbfaba532daffd8。

独立注册表消费者通过 native 运行、JS/Wasm GC 检查，49 个 .mbt 及根清单逐字节匹配，确认缺轴拒绝和 SR 例外实际存在于公开包，见 CONSUMER.md。原始三项 CLI 缺陷也已复跑：缺轴/空轴 query 返回 2 且诊断 TableShape，伪整数参数返回 2 且诊断 Usage。

两次实际修复提交后以发布和验证记录提交收尾，Git 历史原位保留，没有空提交或强制推送。后续证据文档提交的状态在 Actions 单独核验，不以旧版 CI 冒充新代码通过。
