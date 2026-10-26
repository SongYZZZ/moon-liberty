# 针对 Liberty 标准范围意见的补充说明

2026-10-26，项目与唯一正式申报书均为 MoonLiberty，仓库 https://github.com/SongYZZZ/moon-liberty ，本轮版本 0.4.0。正式上传附件为根 PROJECT_APPLICATION.md。

## 固定版本和最终目标

基线固定为 Synopsys Liberty 2017.06。最终目标覆盖该版本合法词法/语法、全标准分组与属性的结构承载、格式层类型/参数/父组/引用规则、逐条正反例及多来源独立往返。数值求值只覆盖标量/一维/二维 NLDM；CCS/LVF 等数据的格式兼容仍属于完整目标，不因不计算波形/统计模型而排除。

## 本轮实际补充

- 增加 18 个有章节、测试与限制说明的规则族：标准组/属性、模板命名空间/引用、0D—3D 表形状、总线范围/成员、状态组与状态表。列明 30 种 2017.06 LVF 矩表的结构校验。
- 修复布尔优先级、超大整数/小数差异漏报、未引号总线范围、缺分号吞并属性、模板错配、负转换时间及写出资源预算等实际缺陷。
- 329 项原生测试、JS/Wasm GC 各 305 项；标准 CLI 25 次。IHP/Nangate 共 384 次独立数值核对，另有 Yosys 结构往返和未修改的 ASAP7 拒绝负例。全部来源和许可证单独列明。
- 申报书、README、模块、Git origin 使用相同项目名与仓库；开发记录保留实质提交，没有空提交凑数。

## 当前真实完成程度

本轮使标准目标更具体，并增加了可运行的验证范围，但不是完整 Liberty 2017.06 的完成声明。完整词法/字段级 schema、所有作用域与引用、特殊根结构及完整高级模型格式规则仍须闭环。compat 明确输出 complete_standard_conformance=false、rule_inventory_exhaustive=false。按最终完整目标验收时，这些仍是实质未完成工作，不能用测试数量替代。

详细证据见 STANDARD_CONFORMANCE.md、FINAL_REVIEW.md、TESTING.md、CORPUS.md；不把本地自查或 CI 通过称为组委会初审/终审通过。
