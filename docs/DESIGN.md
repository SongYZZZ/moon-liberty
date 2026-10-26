# 设计与数据契约

## 数据流

UTF-8 文件 → 有界 token（位置）→ 通用 Group/Node/Atom → Library/Cell/Pin/TimingArc/Table → lint、query、diff。纯核心与异步 CLI 独立分包。官方 async@0.21.2、x@0.5.1 只服务原生 IO；领域解析、单位、网格、逻辑和差异由本项目实现。

Group 保存名称参数、按输入顺序排列的子节点和未知字段。模型保存 source，未建模属性仍能写出、比较和提取。写出后重新解析并逐层核对结构，拒绝手工 AST 通过单字段插入语句。Position 的 offset 和 column 以 UTF-16 代码单元计，line/column 从 1 开始，offset 从 0 开始；LF 推进到下一行。

## 单位与插值

read_units 必须得到 time_unit 与 capacitive_load_unit。parse_unit 返回正的 SI 倍率，拒绝零、负数、无穷、NaN 和未知后缀。query_timing 的 slew_seconds、load_farads、seconds 分别为秒、法拉、秒，raw_value 保留库时间单位值。JSON 会明示 time_unit_seconds 和 capacitance_unit_farads，不混用纳秒与秒。

Table 的 values 按 index_1 行、index_2 列存放。严格递增有限坐标和数组形状在 read_table 和每次 lookup_table 时校验；调用者可以修改公开数组，因此不依赖过期的校验结果。二维使用相邻四角双线性插值，一维使用线性插值，标量返回单值。轴变量决定 slew/load 对应关系，反序轴同样按变量映射；不识别变量显式拒绝。

query_timing 查找指定 cell/pin/related pin、四种组合表类型和可选精确条件；多弧或多表命中拒绝。它不是对网表传播延迟；单个表值也不能代替 STA、波形仿真、工艺签核或芯片功能验证。

## 检查和差异

解析错误抛出 LibertyError；模型中的可恢复问题成为 Finding，以便一次查看多项问题。lint 汇总模型问题、名称重复、引脚及逻辑引用、方向/数值与支持表格规则。顺序稳定，JSON 中不存在的单位和字段为 null。遇到 error 级 finding，时序查询和差异比较拒绝继续。

比较会索引完整 AST 的结构路径：命名单元/引脚以名称定位，时序弧包含相关引脚、时序类型与条件选择信息。注释已在词法层丢弃，属性顺序忽略；有限数值和部分布尔写法归一，未知属性同样纳入。没有做单位变换后的物理等价证明，也不把所有布尔恒等式化简成同一函数。新增、删除、修改包含前后预览；total_changes 独立于展示上限，truncated 与 preview_truncated 防止少显示被误读为无变化。

select_cells 保留指定 cell 与全部非 cell 库级项，避免遗失模板、单位和未知库级配置；输出仍需 lint。它不是在复原缺失数据，不会补造模板。

## 文件与退出码

read_text 先检查普通文件及字节上限，再读取固定长度并严格解码。write_text 在目标目录用随机名字独占创建暂存文件，写入、同步、关闭后改名，默认拒绝已有目标；--force 为显式替换。错误仅清理本次创建的临时文件，不清理其他用户文件。

可执行程序退出码 0 表示成功或无差异；1 表示 lint 检出 error 或 diff 有变化；2 表示使用、格式、IO、歧义或不支持的求值错误。非零必须结合 stderr 或 lint/diff JSON 分析，不能把警告、越界拒绝和确实的库变化混为一类。

## 0.2.0 标准层
StandardEdition 固定到 Liberty2017_06。parse_fragment 和 parse_liberty_sources 在纯核心内按完整语句解析 include，不进行文本拼接；所有输入共用预算，拒绝嵌套 include。compatibility_report 校验库级扩展声明并报告格式/求值覆盖，完整符合性保持 false。CLI source map 是文件名到源码文本的 JSON，显式 IO 与领域解析分离。详细契约见 STANDARD_CONFORMANCE。

## 0.4.0 领域建模边界

同一 pin 分组可声明多个标量名称，模型为每个名称生成可查找记录，保留原始共享 Group；时序表数组共享并在使用时校验。ModelLimits 同时限制展开引脚数和重复验证工作量。AST 的 write/normalize/extract 仍保存原有声明，不把模型展开反写成新的来源。总线与 bundle 未展开时，模型明确警告。标准层的库级/单元级类型环境分别保存，局部遮蔽不会改变全局或兄弟单元。
