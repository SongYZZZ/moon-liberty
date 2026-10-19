# 选题与公开生态检索

检索日期：2026-10-19。选题：MoonLiberty，Liberty 标准单元库解析、NLDM 查询与变更审计。这里记录可复核的公开范围，不保证不存在未公开、未被搜索收录或检索之后新增的作品。

## 实际检查的来源

1. [官方十月活动](https://moonbitlang.github.io/Hackathon2026/)及其公开源码，确认允许原创、移植和生态建设，但要求实质贡献并拒绝重复拆分。
2. [Mooncakes](https://mooncakes.io/)：运行 moon update，检查本机刷新的 3124 个公开包索引 JSON 中的名称、描述和关键词。检索 liberty、nldm、standard-cell、timing-library、cell_rise；未找到同定位包。索引是时间点快照，网站没有提供“所有将来选题不重复”保证。
3. GitHub 仓库和代码查询，除本项目外，未找到同定位的公开 MoonBit 领域实现：
   - gh search repos 'liberty language:MoonBit'
   - gh search repos 'liberty MoonBit in:name,description,readme'
   - gh search repos 'nldm moonbit'
   - gh search code '"cell_rise" language:MoonBit'
   - gh search code '"lu_table_template" language:MoonBit'
4. 网站补充查询 MoonBit Liberty parser、Mooncakes Liberty NLDM。宽泛关键词有不相关项目命中，不能仅凭名称相似认定相同选题。

## 没有采用的候选

MCAP 发现 LilaLola67/moonmcap；Touchstone 发现 guolei-dev/touchstone；RINEX 发现 xuting22/rinex；日历/循环日程方向存在 moon-schedule 等实现；OpenMetrics 存在 moonopenmetrics 等实现。运输时刻方向也存在相关公开作品，保守放弃。这些都没有改名作为新项目。

## 实质范围与边界

Liberty 解析器在其他语言早已存在，不能宣传为全球新发明。区别于通用解析库，本项目实现标准单元、引脚、条件时序弧、模板和网格的领域模型；把秒与法拉映射到声明单位并对越界、歧义显式拒绝；比较完整结构而保留厂商字段；结合实际公开 PDK 样本做独立核对。领域能力由 MoonBit 实现，第三方 PDK 只是测试数据。

后续参赛前仍应查看新增包和公开选题。官方公开页没有提供未公开报名的完整名单，是否与某个未公开参赛项目冲突最终以组委会核验为准。选题检索不能替代该核验。
