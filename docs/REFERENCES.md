# 来源、原创与许可证

领域实现为本仓库原创 MoonBit 代码，非现有 Liberty 实现的移植，没有引入第三方 Liberty 领域运行库。通用语法思想、标准数据格式和独立测试工具不构成“格式全球首创”的主张。

## 运行依赖

- MoonBit SDK/core：编译器与标准库；[官方仓库](https://github.com/moonbitlang/core)。
- [moonbitlang/async](https://github.com/moonbitlang/async) 0.21.2、moonbitlang/x 0.5.1：官方原生异步 IO/相关基础模块；固定在 moon.mod，不是领域算法来源。各依赖保留其原许可证。

## 公开测试数据

[IHP-GmbH/IHP-Open-PDK](https://github.com/IHP-GmbH/IHP-Open-PDK)，Apache-2.0，Copyright 2024 IHP PDK Authors。固定 revision 为 5e6d592e4002946a4616f798c357f0f3c06cf3b6，文件：

ihp-sg13g2/libs.ref/sg13g2_stdcell/lib/sg13g2_stdcell_typ_1p20V_25C.lib

仓库本地 tests/fixtures/ihp-sg13g2-typ.lib，保持原始内容和版权头。SHA-256 为 7677a8918689f452e80405ad16a83e744709342574f2aedcc507c2758986b396。IHP 公开 PDK 是测试样本，不表示本工具获得工艺认证。根 NOTICE 记录来源，原始授权文本在 LICENSE 中。

basic.lib 和 bad-reference.lib 为本项目自编合成测试数据。

## 独立测试工具

[liyanqing1987/libertyParser](https://github.com/liyanqing1987/libertyParser)，GPL-2.0，revision 77440f598eee8291ddf9393e397711645cf0ee11。由 fetch-oracle.ps1 下载到 Git 忽略的 .tools/oracle，连同其 LICENSE 保留，作为独立 Python 进程的测试输入来源；没有复制进提交的实现、发布包或运行时依赖。本项目的 oracle_check.py 为原创适配和数值核对脚本。调用仅使用完整文件解析接口，不使用参考工具带 shell 拼接的单元提取路径。

对照范围是明确样本的结构与数值一致性，不等同于完整 Liberty 标准认证。不能把 Python 工具的已有功能声称为本项目原创发明。MoonLiberty 的交付价值是 MoonBit 可复用实现、显式单位与拒绝策略、可接入维护流程的检查和变更报告。
