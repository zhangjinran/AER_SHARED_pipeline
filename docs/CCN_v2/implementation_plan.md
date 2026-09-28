# CCN OMCAM v2 冻结实施计划

状态：FROZEN  
冻结日期：2026-09-21  
工程根目录：`F:\AER_SHARED_PIPELINE`

## 1. 目标与边界

保留现有正式 `T_all`，不修改或重新发布 T_all、CALIPSO_STATS、Chapter 4、Chapter 5。

CCN v2 从正式 `T_all` 开始，实现尽可能接近 ESSD/OMCAM 科学方法的独立支路。产品正式名称为：

`CCN OMCAM v2 from project T_all`

不得称为 ESSD 2023 strict reproduction。以下限制必须写入所有正式 manifest：

- upstream QC 是项目现有 aerosol-valid QC，不含完整 ESSD Table 1 QC；
- RH 来源为 ERA5；
- T_all 不含 clear-air bins；
- 正式均值定义为 retained aerosol-valid samples 上的 conditional mean；
- clear-air samples 不进入 denominator。

## 2. 冻结目录

所有 CCN v2 代码必须位于：

`code\CCN_v2\`

其子目录固定为：

- `config`：唯一配置源、产品键、网格和 component 定义；
- `priors`：先验生成与先验验证脚本；
- `science_core`：不负责文件发布的纯科学计算函数；
- `producers`：日产和月产 producer；
- `publishers`：正式发布、manifest、inventory、`_SUCCESS`；
- `consumers`：只读取正式产品的绘图程序；
- `batch`：日/月总控和启动脚本；
- `validation`：Unit、sample、day、product Gate。

先验数据固定在 `inputs\priors\ccn_v2\`。正式产品固定在：

- `products\ccn_v2\ccn_grid_day\`
- `products\ccn_v2\ccn_grid_monthly\`

候选、日志、诊断和图片只允许进入 `runs\run_ccn_v2_*\`。不得写入 code、inputs 或正式 product 日期目录。

## 3. 科学定义

内部只使用五个物理 component：

1. marine
2. dust
3. polluted_continental
4. clean_continental
5. elevated_smoke

CALIPSO subtype 路由：

- Type 1 -> marine
- Type 2 -> dust
- Type 3 -> polluted_continental
- Type 4 -> clean_continental
- Type 5 -> dust + polluted_continental
- Type 6 -> elevated_smoke
- Type 7 -> dust + marine

Type 5/7 使用 depolarization 端元 0.05 和 0.31 分离。端元只用于 mixed 分离，不得作为全局过滤范围。

固定 lidar ratio：dust=44 sr、polluted continental=70 sr、marine=23 sr。

积分下限：dust=0.10 um（N100）；其他 component=0.05 um（N50）。正式主产品为 CCN020；CCN025 和 CCN040 分别由 1.35 和 1.70 倍 CCN020 派生。

## 4. RH 与先验查表

使用 T_all 中 ERA5 ambient RH。MOPSMAP 先验保存为两列：第一列 RH percent，第二列 normalized extinction。程序必须按 RH 坐标插值，禁止用裸行号读取，禁止把第一列当 extinction。

采用 `alpha_ambient / alpha_n(RH)` 路线时，不得再次除以额外 GF，避免双重湿度修正。

Marine 必须使用新 AERONET 参数和 sphere/Mie。Dust 使用 spheroid。其他 component 的 optical geometry 在 prior manifest 中明确记录。

## 5. 网格和聚合

水平网格：2 degree latitude x 5 degree longitude。

垂直坐标：从 canonical CALIPSO altitude axis 冻结 0--8 km 的 133 个中心层，实际间距约 0.060 km；不得凭空重建另一套中心。

每个保留的 aerosol sample 产生五个 component contribution，不存在的 component 记零。所有 component 使用同一个 `sample_count` denominator，因此必须满足：

`CCN_total = CCN_marine + CCN_dust + CCN_pc + CCN_cc + CCN_es`

日产品保存 component sum、total sum、sample count 和 occurrence diagnostics。月产品只通过逐日 sum/count 累加得到，不允许无权平均 daily mean。

## 6. 实施阶段

### Phase 1：先验与科学核心

- 建立集中配置；
- 实现 component 路由和 mixed dust 分离；
- 实现按 RH 坐标读取 normalized extinction；
- 修复 Marine sphere/Mie 先验生成；
- 建立 conversion-factor Unit Gate。

### Phase 2：单样本与单日 Gate

- Type 1--7 各选代表样本；
- 覆盖 depol 小于 0.05、中间区间和大于 0.31；
- 输出 beta、component extinction、alpha_n、S_V、N50/N100、CCN；
- 使用 2007-01-01 完成单日 3D 产品 Gate。

### Phase 3：旧/新差异检查

- 比较数量级、覆盖率、分位数和空间相关性；
- 旧产品存在已知科学错误，不要求 maxdiff=0；
- 对 Marine 和 Dust 主导区变化给出解释。

### Phase 4：月度生产

- 生成 2007-01 daily v2；
- 生成 2007-01 monthly v2；
- 生成 total、五 component、贡献率和垂直诊断图；
- v2 全部 Gate 通过后，旧 CCN 产品仅标记 SUPERSEDED，不直接覆盖。

## 7. 强制 Gate

Gate A：先验、shape、RH 列、单位和 conversion factor。  
Gate B：Type 路由、mixed beta 守恒、N50/N100、非负有限值。  
Gate C：90 x 72 x 133、五 component + total、sum/count、月度 pooled mean。  
Gate D：绘图只读取正式月产品，不重新执行 OMCAM。

任一 Gate 未通过时，publisher 不得写正式日期/月目录，也不得创建 `_SUCCESS`。

## 8. 变更纪律

本文件是后续实现的冻结依据。除非用户明确要求修改计划，否则不得调整总体架构、产品定义、目录边界和实施顺序。实现细节可以为适配 MATLAB 或现有文件格式而调整，但必须保持上述科学合同和 Gate 不变。
