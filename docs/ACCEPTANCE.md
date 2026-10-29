# 九项验收核对（2026-10-29）

规则来源为用户在本次对话提供的《验收指南》。已审核通过选手无需再提交验收表格，只需持续开发并将内容上传 GitHub；本记录不推定项目已经获得官方资格审核或最终验收通过。

| 项 | 要求 | 仓库证据及边界 |
| --- | --- | --- |
| 1 | MoonBit 为主，moonc 不低于 0.10.16 | 核心/CLI 均为 MoonBit；SDK/core 固定 0.10.16+b1a0e846e；toolchain.json、check-toolchain.py --pinned、CI 日志。旧 0.10.14 已实际验证被门禁拒绝。 |
| 2 | GitHub 公开，提交清晰 | SongYZZZ/moon-liberty，默认分支 main；公开状态实际读取，保留连续实质提交。 |
| 3 | 结构清楚，能完成声明核心功能 | 语法、领域模型、单位/表、逻辑、查询、差异、标准规则和 IO 分包；九命令代表用例、正反例通过。完整 2017.06 是尚未实现的最终目标，不能把本项理解为全部标准完成。 |
| 4 | README 目标、安装、用法、示例可复现 | README 给出 SDK 下限、隔离安装/激活、构建与实际样本命令；SUPPORT 与标准契约说明范围。 |
| 5 | CI 包含检查、构建、测试 | .github/workflows/ci.yml 固定 SDK/core，执行严格 check、release build、三后端 test，以及 CLI/独立工具核对；版本门禁防止误用旧编译器。 |
| 6 | 至少一个运行示例 | examples/inspect 和 examples/query 均实际运行，并纳入 CI，使用固定公开 IHP 库。 |
| 7 | 核心路径测试 | 348 native；核心 JS/Wasm GC 各 323；27/29/66 次三类 CLI 流程、55 次 Decimal 对照、IHP/Nangate 共 384 次实库数值核对及往返/提取。测试数不代表全部标准覆盖或所有错误都已排除。 |
| 8 | 发布 Mooncakes | 0.4.3 已实际发布（200 OK）；独立注册表消费者通过 native 运行及 JS/Wasm GC 检查，49 个源文件、根清单及 toolchain.json 一致，见 [发布证据](CONSUMER.md)。 |
| 9 | OSI 许可证及参考合规 | 根 LICENSE 为 [OSI 认可的 Apache-2.0](https://opensource.org/license/apache-2.0)，NOTICE/REFERENCES 记录测试数据和独立读取器的固定来源与许可证；无外部 Liberty 源码作为产品实现依赖。 |

本轮必要迁移包括 Json(value)、Int32 规范名称与默认参数标记；九个命令代表输入的 JSON 和三类文件写出与 0.4.2 对比一致。六份生成接口仅两份出现 Int→Int32 的规范名称变化，归一后逐字一致；没有扩大物理计算模型。机读证据在本地 artifacts/migration-043.json。

工具链 SDK SHA-256 与官方下载侧 .zip.sha256 核对；core 固定官方 HTTPS 归档及对应 moon.mod，记录计算出的哈希，未将其描述成官方独立发布的校验值。安装与激活只影响本项目目录/当前终端，旧软件、认证和全局环境原位保留。

工程验收证据不能代替对申报承诺的判断。全部字段级 schema、特殊结构及高级模型完整规则的未完成项继续见 [标准契约](STANDARD_CONFORMANCE.md)，本轮没有删减该最终目标，也不以新指南为由宣称完整兼容完成。最终发布、远程 CI 与本轮结论见 [复查报告](FINAL_REVIEW.md)。

最终发布源码 24b19b86bc4090b73dafcf0fb7d032d5f30a03d7 的[全套 CI](https://github.com/SongYZZZ/moon-liberty/actions/runs/40861285604)通过，包含编译器门禁与两个实际示例。第 3 项所涉及的完整标准最终目标仍未完成，不能把其余工程证据视为对此缺口的豁免。
