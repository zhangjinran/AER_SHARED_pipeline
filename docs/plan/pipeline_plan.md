# AER_STRUCTURE_PIPLINE 总体计划

状态：规划中。VSD 的详细、可核验步骤见 [planVsd.md](planVsd.md)。计划不等于已完成。

## 目标与边界

旧 `F:\AER_SHARED_PIPELINE` 只作为只读历史基线。新 `F:\AER_STRUCTURE_PIPLINE` 以全球 APRO MAT、ERA5 MAT 为主要输入，建立模块化、可追溯的处理管线，逐步支持 VSD、N50、CCN、AERONET。模块通过有明确科学定义、字段、单位、来源和 Gate 的中间产品连接。本阶段不设计后三者的反演算法，也不沿用旧项目中已丢弃 bin/廓线溯源的 T_all 作为 VSD 输入。

## 当前结构与职责

```text
F:\AER_STRUCTURE_PIPLINE\
├─ code\
│  ├─ run\       通用入口（空）
│  ├─ utils\     可复用实现（空）
│  ├─ configs\   长期配置（空）
│  └─ test\      测试代码（空）
├─ product\      唯一有效的正式/中间/先验产品（空）
├─ run\          实际执行的配置、日志与分析结果（空）
└─ docs\
   ├─ inference\ 三篇用户提供的科学论文
   └─ plan\      总体计划与 VSD 分计划
```

不为 Git 跟踪空目录而添加无意义文件，不提前建立后续模块目录。正式代码不放 `run/`，正式产品不放运行记录目录。

## 第一模块 VSD

输入是 MOPSMAP（用户称 MOSMAP）所需先验、全球 APRO MAT、ERA5 MAT。基础粒度为**廓线中的垂直 bin**；一条记录至少有经纬度、时间、bin 中心高度、`type`、`profile_id`、`sample_id`、`source_hdf` 和干态参数式 VSD。无气溶胶 bin 以 `type=0` 保留；一个 bin 多类别取第一 plane，不自行融合。成功反演的 Type 5/7 物理 bin 分别输出两条同源组分记录，用 `component` 区分尘和非尘；反演失败的气溶胶 bin 删除并在日志中计数。每天一个 VSD MAT。具体数值、单位和来源验证见分计划。

## 顺序里程碑

1. 读三篇论文，核验旧基线最新的双峰 NVSD 参数、532 nm 折射率、`α_n(RH)` 光学查表、MOPSMAP 生成方法、单位 Gate 与哈希。经确认后只转移必要的正确先验到新项目 `product/`；本次尚未转移。
2. 审计全球 APRO 日 MAT、ERA5 小时 MAT 的字段、shape、坐标、单位、缺失值、AVD/QC 和文件完整性；记录旧基线代码可参考与不可复用的地方。
3. 冻结 VSD 的干/湿物理定义、bin 与廓线索引、混合型组分、无气溶胶语义、输出格式、配置及 Gate，然后才编写通用生产入口和可复用组件。
4. 先单轨道结构/数值 Gate，再完整单日 Gate，最后考虑月度处理。日志归 `run/.../logs/`、正式 MAT 归 `product/`，不得为每个日期写一份脚本。
5. VSD 通过后，分别规划 N50、CCN、AERONET；不在当前计划臆造其算法。

本次仅完成只读调查和计划改写，没有运行 MATLAB/MOPSMAP、生成产品、转移先验、修改旧 Pipeline 或执行 Git 操作。Git 分支与逐文件提交范围须另行交用户审阅。
