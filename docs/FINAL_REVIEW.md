# MoonLiberty 0.4.3 验收复核（2026-10-29）

## 结论

按本次提供的九项《验收指南》处理新增工具链下限：原 CI/项目固定 0.10.14 不满足 moonc≥0.10.16，现已实际迁移到 SDK/core 0.10.16+b1a0e846e，完成严格构建与核心回归。逐项要求、证据及范围限制见 [九项核对](ACCEPTANCE.md)。该工程复核不是官方验收结论；完整 Liberty 2017.06 仍有实质未完成项，尤其须由审核方结合申报承诺判断第 3 项。上一轮事实保留在 [0.4.2 报告](history/FINAL_REVIEW_0_4_2.md)。

## 必要修正

- 新增 toolchain.json 固定 SDK/core 及下载哈希；脚本安装到 .tools/moon016，激活只调整当前终端环境，原有 SDK、认证及全局配置保留。
- scripts/check-toolchain.py 检查实际编译器≥0.10.16；CI 进一步要求固定 SDK/core 一致。本机旧 0.10.14 实际被拒绝，固定 SDK/core 通过。安装器再次运行也不会覆盖已有环境。
- 新版标准库将旧 to_json 调用标为弃用，导致原 --deny-warn 失败。已迁移为 Json(value)，不屏蔽警告；格式器另按 SDK 规范改写 Int32 和默认参数标记。
- CI 固定新 SDK/core，保留 check/build/test/CLI/独立核对，并新增两个 README 示例的实际执行。README 给出一条可复现的隔离安装、当前终端激活与版本检查流程。

## 实测证据

SDK/core 0.10.16+b1a0e846e；moon 0.1.20261020。严格编译、格式、接口生成、release 构建通过；348 native，核心 JS/Wasm GC 各 323。两个例子运行，IHP 库仍为 84 单元、285 引脚、384 弧、1199 表，查询结果约 1.1540884836886305e-10 秒。

原 CLI 27 次、标准 CLI 29 次、不变量 66 次（含 55 次 Decimal）；IHP 312、Nangate 72 次真实库数值核对及往返/提取通过。ASAP7 原始缺分号负例保留。九个命令的代表输入与 0.4.2 二进制对照：退出码和 JSON 相等，normalize/extract/expand 文件逐字节相同。六份接口只有 Int→Int32 的规范名称差异，归一后相同；不声称原始接口文件哈希不变。

当前 49 个 MoonBit 文件、7860 行有效代码（实现 4915、测试 2945）。算法、求值维数和命令集合未扩大。机器记录位于本地 artifacts/migration-043.json；此前 SDK/输出快照在 D:/Dev/Temp/moon-liberty-sdk016-20261029。上游 async 的 Windows C4005 提示仍存在，未把它描述为零警告。

## 提交与范围

仓库公开、默认分支 main，申报书/模块/README/Git origin 保持同一项目。根 Apache-2.0 LICENSE、NOTICE、固定数据及独立测试工具来源复核，参见 REFERENCES.md。使用已安装 osc2026-guide 的工程检查，但此次新增九项和 0.10.16 下限以用户提供的指南为准，不沿用技能中较旧的版本门槛。

已审核通过选手按指南无需另交验收表格，保持 GitHub 更新即可；本记录不推定项目已审核通过，不发送邮件或代填表格。最终发布和消费者证据见 CONSUMER.md，将在实际发布后补记。

全量字段级 schema、全部格式引用/父组约束及特殊/高级模型规则尚须闭环，详见 [完整标准契约](STANDARD_CONFORMANCE.md)。编译器升级、测试通过及发布不能替代这些实现，也不能据此宣称完整 2017.06 或保证官方终审通过。

## 最终发布证据

0.4.3 已实际发布，服务器返回 200 OK；标签 v0.4.3 指向 24b19b86bc4090b73dafcf0fb7d032d5f30a03d7，其[全套 CI](https://github.com/SongYZZZ/moon-liberty/actions/runs/40861285604)通过，包括版本门禁、check/build/test、两个示例与独立核对。CI 的 job 级 SDK 路径使用 github.workspace 可用上下文，初次无任务的配置问题已修正后重新成功执行，未将该失败版本发布。归档 SHA-256：8749c80a9a261e11ba146525aae4fe30e2a60b5e4f8efef6e108f5acd334e9d0。

独立目录从 Mooncakes 精确下载 0.4.3，在固定 0.10.16 SDK/core 下 native 检查/运行、JS/Wasm GC 检查通过，49 个源文件、根清单及工具链配置与发布源逐字节一致，见 CONSUMER.md。安装、旧编译器拒绝、九命令对照、完整回归、实际发布和公开消费均完成；第 3 项的完整标准承诺仍按前文保留未完成状态。后续证据文档提交与发布源的 CI 分别核对。
