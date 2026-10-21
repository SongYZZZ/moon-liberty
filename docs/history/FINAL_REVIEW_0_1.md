# 报名及后续验收自查

核对时间：2026-10-19。这是本地工程与公开证据自查，不是组委会审核结论。使用 osc2026-guide 的通用工程检查项，赛事日期及报名规则以当日十月官网为准；没有把该技能的八月日程套用到十月。

## 总体判断

项目已经形成可以下载和复现的独立 MoonBit 工具，不是空仓库或只有申请书。正式申报材料与作品同名、同地址。公开生态检索未发现同定位的现有 MoonBit 作品，但不能覆盖未公开报名或检索之后新增的项目。

| 检查项 | 证据 |
| --- | --- |
| 有效 MoonBit 项目 | SDK/core 0.10.14+7d59c7ec9；moon.mod / moon.pkg 识别正确 |
| 检查、测试、构建 | check --deny-warn、test --deny-warn、fmt --check、info、release build 通过 |
| 测试覆盖实际路径 | 205 项 native；185 项 JS 和 185 项 Wasm GC；18 次 CLI 执行检查 |
| 独立互操作 | 固定 Apache-2.0 IHP 数据，312 次数值查询、完整结构往返、提取核对 |
| CI | [52228a4 的全流程成功运行](https://github.com/SongYZZZ/moon-liberty/actions/runs/39235250112)，包括独立对照；后续提交状态见仓库 Actions |
| 可复用发布包 | SongYZZZ/moon-liberty 0.1.0，moon publish 返回 Server status: 200 OK |
| 公开查询 | moon search liberty --json 返回 version 0.1.0、summary_version 0.1.0、is_summary_current=true |
| 独立消费者 | 在全新独立项目 moon add 下载 0.1.0，check --deny-warn、run、JS check 通过 |
| 原生例子 | examples/inspect、examples/query 已实际运行 |
| 源码规模 | 36 个 .mbt 文件，4442 行非空且非整行注释的 MoonBit；包括测试，排除依赖、生成文件和构建输出，不将数据文件计入代码 |
| 提交历史 | 此报告之前 main 已有 13 次实际功能、修复、验证及文档提交；脚本要求至少 11 次 |
| 开源及来源 | 根 Apache-2.0 LICENSE / NOTICE，第三方数据与可选独立工具分别记录 |
| 身份一致 | README、PROJECT_APPLICATION.md、moon.mod 与 Git origin 指向 SongYZZZ/moon-liberty |
| 首次阅读审查 | 独立读者核对八项字段、三场景、范围、来源与正文；修正“最小库”措辞后无重大矛盾 |

发布归档 SHA-256：2d13f1dde12bfe4b2c9ca862bdff0ddc64fed633a0906be997be9169b8ff76d3。通过公开 download.mooncakes.io 地址独立下载后与本次上传归档一致。发布实现对应 52228a49d7ac51e08d07d36ca3ce0bdeb40b2e70；后续报告、提交门槛及材料措辞可继续更新，不追改已发布版本。

## 实际修复的错误

- 公开 AST 写出前后核对结构，防止单个手工字段插入额外语句；包含定向回归。
- 字符串默认比较不符合预期字典序，改为明确字符顺序，逻辑输入与差异报告顺序固定。
- CLI 单位明示、默认越界拒绝，条件弧与多表歧义拒绝，避免猜测。
- 首次 Linux CI 发现父目录已存在时递归 mkdir 行为差异，已修复，随后整个 CI 成功；没有隐藏失败的测试。
- 未支持的求值不会伪造为零或“通过”。格式化、当前规则 lint 和完整标准符合性分别说明。

## 待参赛者办理或确认

- 官方十月页面写明最多提交 3 个项目。已被拒绝的旧报名如何计入，以表单和组委会记录为准；本地无法确认剩余名额。
- 官方群的身份标注和最终表单附件由参赛者本人确认。本次没有代填表单、发邮件或群消息。
- 飞书完整章程未成功读取，只核对了官网公开规则与用户提供的八项申报要求，不能把不可访问条文写为已逐条通过。
- 持续扩充更多公开厂商/工艺样本；一个 IHP 样本及有界模型并不能证明全部 Liberty 方言或商业签核级正确性。范围见 SUPPORT。

## 正式材料入口

唯一正式申报书：根 PROJECT_APPLICATION.md。项目名称与仓库复制如下：

MoonLiberty：芯片标准单元库的 Liberty 解析、NLDM 时序查询与变更审计工具  
https://github.com/SongYZZZ/moon-liberty

不要把参考项目、测试工具或旧报名附件的仓库地址填入本项目仓库字段。报名、复审和终审结果由组委会决定；目前有证据支持的是上述已完成工程检查。
