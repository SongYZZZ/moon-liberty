# 对 MoonLiberty 初审意见的补充说明

2026-10-21，仓库 https://github.com/SongYZZZ/moon-liberty ，源码/本轮发布目标 0.2.0。

本次意见认可单位化查表和结构审计的价值，主要指出：自研解析器未固定标准版本，缺少完整格式符合性的终点，以及该终点与受限求值范围的关系。此前材料在这三项上确实不够明确，本轮按以下内容修正。

## 已作出的具体修改

1. **版本固定。**指定 Synopsys Liberty User Guides and Reference Manual Suite **Version 2017.06**，给出官方获取入口、核对版本的来源及不分发标准手册的说明。没有把厂商标准误称为本项目自创格式。
2. **完整目标固定。**v1.0 的格式验收覆盖所选版本全部合法结构及字段的读写与原义保留、格式层参数/类型/作用域/引用约束、逐条正反例和跨工具往返。不能把 NLDM 子集当作完整格式兼容终点，也不能只用一个真实库的成功解析来证明完整符合。
3. **求值范围独立。**完整格式目标包含 CCS/LVF、总线、状态及功耗数据；0.2.0 对这些结构保留、审计并报告不求值。数值求值器仍有界，组合 SI 查询仅四类 NLDM 表，不实现波形、统计模型或路径 STA。
4. **有实现的证据。**新增显式 --standard 2017.06 的 compat、受控 include 展开及 expand 命令、define/define_group 检查；完整符合性、已实现检查通过、结构往返和求值覆盖分列，当前完整符合性保持 false。
5. **案例与工程回归。**三个原创场景有 13 次 CLI 断言，252 项 native 测试；原有 IHP 真实数据的 312 次独立查询核对保留。新增用例进入 CI，而不是只修改文字。
6. **材料统一。**正式附件仍只有根 PROJECT_APPLICATION.md；README、支持矩阵、标准契约、版本家族清单和终审技能自查同步更新。

## 可直接复核的位置

- [一页申报书](../PROJECT_APPLICATION.md)
- [版本、完整兼容终点与求值边界](STANDARD_CONFORMANCE.md)
- [状态与开放项的机器可读家族矩阵](standards/liberty-2017.06.json)
- [三个案例及复现命令](STANDARD_CASES.md)
- [本轮技能自查](FINAL_REVIEW.md)
- 新实现 includes.mbt、compatibility.mbt；新测试 includes_test.mbt、compatibility_test.mbt 和 scripts/check-standard.py。

## 如实说明当前进度

本次补充界定的是明确的完整格式目标，并已实现、验证一部分此前缺少的关键规则。0.2.0 仍未完成全版本的字段级 schema、全部作用域/引用负例和多来源真实语料闭环；因此没有声称当前已完整符合 Liberty 2017.06，也不将本地工程检查通过当作组委会初审或终审通过。

以上文本供参赛者修改报名表时说明本轮变化；未代为发送邮件、联系组委会或提交表单。
