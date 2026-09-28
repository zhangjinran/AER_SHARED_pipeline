# Chapter 5 OMCAM v2 冻结修复计划

状态：FROZEN  
冻结日期：2026-09-22  
工程根目录：`F:\AER_SHARED_PIPELINE`

## 1. 修复目标与边界

建立独立的 `Chapter5_v2` 支路，修复当前 Chapter 5 中已经确认的先验和 OMCAM 实现错误，同时保留 Chapter 5 原有的科学产品定义、七类 CALIPSO subtype、5°×5° 网格、昼夜分类、10 km 高度门限和 clear-air denominator。

本修复不修改、不覆盖或重新发布以下上游产品：

- 正式 `T_all`；
- 正式 `CLEAR_AIR_STATS`；
- CCN_v2 日/月产品；
- 旧 `CALIPSO_STATS stats-v1`；
- 旧 Chapter 5 月产品和历史图片。

需要重新生成的链路固定为：

```text
formal T_all
    +
immutable OMCAM-v2 priors
    ↓
CALIPSO_STATS Chapter5-v2
    +
existing formal CLEAR_AIR_STATS
    ↓
CHAPTER5_MAP_STATS v2
    ↓
Chapter 5 v2 plots
```

## 2. 已确认的旧实现问题

旧 Chapter 5 不能继续作为正式科学基线，原因固定记录如下：

1. Marine 使用旧粒径谱和折射率参数，而不是最新 Marine AERONET 参数；
2. `Extinction_Normalized.mat` 的每个 component 是 `[RH, normalized extinction]` 两列，但旧 `Calc_Nd_OMCAM.m` 读取了第 1 列 RH；
3. 旧函数使用 `1e6` 体积尺度换算，与完整旧 OMCAM 实现及 CCN_v2 Unit Gate 验证的 `1e9` 不一致；
4. 旧代码以裸行号查表，没有按照 RH 坐标插值；
5. 旧产品键没有编码先验版本和 OMCAM 修订版本，因此不得原地覆盖。

## 3. 冻结目录

所有新代码必须位于：

`code\Chapter5_v2\`

子目录固定为：

- `config`：唯一配置源、产品键、先验位置和科学常量；
- `science_core`：sample-level OMCAM 数浓度计算，不负责文件 I/O、网格化或发布；
- `producers`：日 `CALIPSO_STATS_v2` 和月 `CHAPTER5_MAP_STATS_v2` producer；
- `publishers`：正式发布、manifest、input inventory 和 `_SUCCESS`；
- `consumers`：只读取正式月产品的绘图程序；
- `batch`：单日、单月总控与续跑入口；
- `validation`：Unit、sample、day、month、regression Gate。

计划、合同和 Gate 报告分别进入：

- `docs\Chapter5_v2\`
- `runs\run_chapter5_v2_*\reports\`

候选文件、日志、诊断和图片只能进入对应 run；不得写入 `code`、`inputs` 或正式 product 日期目录。

## 4. 冻结输入

### 4.1 T_all

只读取正式发布且具有 `_SUCCESS` 的：

`products\t_all\tall__ap-final-v1__era5-real__adapter-v1__qc-v1\YYYY\MM\DD\T_all_YYYYMMDD.mat`

不得重新执行 CALIPSO/ERA5 adapter，不得修改 T_all。

### 4.2 OMCAM-v2 先验

只读取 CCN_v2 已通过 Unit Gate 的 immutable input：

`inputs\priors\ccn_v2\omcam_v2__acp-table4-unitgate-v1\`

包括：

- `Parameter_OMCAM_v2.mat`；
- `Extinction_Normalized_v2.mat`；
- `manifest.txt`。

不得复制出第二套可漂移的先验，不得回退到旧 `Parameter_Particle_CALISPO.mat` 或旧 `Extinction_Normalized.mat`。

### 4.3 CLEAR_AIR_STATS

继续读取正式：

`products\clear_air_stats\clear__ap-final-v1__grid5deg__z60m__clear-v1\YYYY\MM\DD\`

clear air 来自 Final MAT 的 `Atmospheric_Volume_Description`，定义保持：

```matlab
Feature_Type = bitand(AVD, 7);
clear_mask = Feature_Type == 1;
```

本次先验修复不影响 clear-air 识别，因此禁止无理由重算 `CLEAR_AIR_STATS`。

## 5. 冻结科学定义

### 5.1 物理 component

内部使用五个 component：

1. marine；
2. dust；
3. polluted continental；
4. clean continental；
5. elevated smoke。

先验参数、shape、kappa、normalized extinction 和单位合同必须与 CCN_v2 完全一致。

### 5.2 CALIPSO subtype 路由

Chapter 5 最终仍保存原始 Type 1–7，不改成五分类：

- Type 1 → marine N50；
- Type 2 → dust N100；
- Type 3 → polluted continental N50；
- Type 4 → clean continental N50；
- Type 5 → dust N100 + polluted continental N50；
- Type 6 → elevated smoke N50；
- Type 7 → dust N100 + marine N50。

Type 5/7 必须先按与 CCN_v2 相同的 depolarization 端元拆分 dust/non-dust extinction，再分别进行 OMCAM，最后按上述 Chapter 5 legacy 定义相加。不得在月聚合阶段重新拆分或猜测。

### 5.2.1 Sample provenance 与组合顺序

Chapter5_v2 只复用 CCN_v2 已验证的先验和 sample-level component physics，不得读取或相加 CCN_v2 已聚合的五组分 GRID。

共同 sample-level 结果至少必须保留：

```text
sample_id
original_type
N50_marine
N100_dust
N50_polluted_continental
N50_clean_continental
N50_elevated_smoke
```

`sample_id` 必须在一个正式 T_all 日产品内唯一，并且可以追溯到原始 T_all 行；`original_type` 必须直接来自同一行 T_all 的 CALIPSO Type，不得从 component 或网格位置反推。

Chapter 5 adapter 必须逐行组合：

```text
original_type == 1: value = N50_marine
original_type == 2: value = N100_dust
original_type == 3: value = N50_polluted_continental
original_type == 4: value = N50_clean_continental
original_type == 5: value = N100_dust + N50_polluted_continental
original_type == 6: value = N50_elevated_smoke
original_type == 7: value = N100_dust + N50_marine
```

Type 5/7 的加法只允许发生在同一个 `sample_id` 内。完成 sample-level Type value 后，才允许按 `original_type`、位置、Day/Night 和月份进入 Chapter 5 聚合。

以下做法明确禁止：

- 将聚合后的 CCN_v2 dust map 与 marine/PC map 相加；
- 按空间网格重叠推断 Type 5/7；
- 把 Type 2/5/7 的 dust component 混合后再尝试恢复原始 Type；
- 把 Type 1/7 的 marine component 混合后再尝试恢复原始 Type；
- 在丢失 `original_type` provenance 后重建七类 Chapter 5 产品。

### 5.3 Mixed aerosol

冻结参数：

- non-dust depolarization endpoint = 0.05；
- dust depolarization endpoint = 0.31；
- dust lidar ratio = 44 sr；
- polluted continental lidar ratio = 70 sr；
- marine lidar ratio = 23 sr。

必须满足 mixed backscatter 守恒：

`beta_dust + beta_nondust = beta_total`

### 5.4 数浓度阈值

- dust：积分半径 `0.10–15 µm`，即 N100；
- non-dust：积分半径 `0.05–15 µm`，即 N50。

因此 Chapter 5 图中 Type 2、5、7 不是严格意义上的统一 N50：Type 2 是 N100 dust，Type 5/7 包含 N100 dust。绘图标题、caption 和 manifest 必须明确说明，禁止继续笼统标成所有类型均为 N50。

### 5.5 RH、消光查表和单位

- RH 来源：T_all 中 ERA5 RH；
- 有效范围：`0 <= RH <= 99`；
- normalized extinction 必须按表格第 1 列 RH 坐标，对第 2 列数值进行线性插值；
- 禁止以行号代替 RH 坐标；
- 禁止读取第 1 列作为 extinction；
- `alpha_ambient / alpha_n(RH)` 路线不得再次应用额外 GF；
- 体积尺度换算固定使用 CCN_v2 Unit Gate 已验证的 `1e9`；
- 非有限、非正 extinction 或 prior lookup 失败的 sample 必须标记 invalid，不得回填 0、均值或默认 RH。

### 5.6 与 CCN_v2 的边界

Chapter5_v2 可以复用已经验证的 OMCAM component 计算逻辑，但不得复用 CCN-specific 输出定义：

- 不乘 supersaturation factor / `fss`；
- 不生成 CCN020/025/040；
- 不使用 2°×5°×0–8 km CCN 网格；
- 不使用 retained-aerosol conditional mean；
- 不移除 clear-air denominator。

允许复用的范围固定为：

- immutable OMCAM-v2 参数；
- RH/normalized-extinction 查表方法；
- mixed dust/non-dust backscatter 分离方法；
- component extinction、volume scale 和 N50/N100 的 sample-level 计算。

禁止复用的范围固定为：

- CCN_v2 五组分日/月 GRID；
- CCN020/025/040 和 supersaturation factor；
- CCN_v2 的网格、垂直范围和 denominator；
- 任何已经丢失 `sample_id × original_type` provenance 的聚合结果。

## 6. 日产品定义

正式日产品类型：`CALIPSO_STATS_CH5_V2`。

建议产品键冻结为：

`stats-ch5v2__tall-v1__era5-rh__omcam-v2__grid5deg__stats-v2`

目录：

`products\calipso_stats_chapter5_v2\<product_key>\YYYY\MM\DD\`

内容至少包括：

- `CALIPSO_STATS_CH5_V2_YYYYMMDD.mat`；
- `manifest.txt`；
- `input_inventory.csv`；
- `_SUCCESS`。

每个 retained sample 必须保留：

- Lon、Lat、UTC、Height、DayNight；
- original Type；
- RH、Ext、Back、Depol；
- component number contributions；
- 最终 Chapter 5 `Nd_dry_OMCAM_v2`；
- valid/invalid 标志或等价诊断。

日产品必须能够审计 Type 5/7 的 dust 和 non-dust contribution，不允许只保存一个无法追溯的总值。

## 7. 月产品定义

正式月产品类型：`CHAPTER5_MAP_STATS_V2`。

建议产品键冻结为：

`ch5map__stats-ch5v2__clear-v1__grid5deg__z10km__map-v2`

目录：

`products\chapter5_map_stats_v2\<product_key>\YYYY\MM\`

月产品只允许从冻结日期清单中的正式日产品累加：

```text
nd_sum(type) = Σ valid aerosol sample Nd(type)
aerosol_count = Σ valid aerosol samples
clear_count = Σ clear-air samples
map(type) = nd_sum(type) / (aerosol_count + clear_count)
```

固定约束：

- 5°×5°；
- Day/Night 分开累加；
- 高度 `<=10 km`；
- 先累加 sum/count，最后除法；
- 禁止无权平均日产均值；
- 日期清单必须在月任务开始时冻结一次，日生产、月聚合和绘图使用同一份清单；
- 冻结清单中缺少正式日产品必须报错，不得静默缩小月份范围；
- 原始 Final MAT/T_all 不存在的日期必须在冻结清单形成阶段标记 missing 并跳过。

## 8. 绘图定义

绘图 consumer 只能读取正式 `CHAPTER5_MAP_STATS_V2`，不得重新执行 OMCAM 或 clear-air 统计。

输出必须进入独立 run：

`runs\run_chapter5_v2_*\plots\chapter5_v2\YYYYMM\`

图必须：

- 保持现有 Chapter 5 可比较的全球投影和布局；
- 明确标注月份、Day/Night、5°网格、10 km 门限；
- 明确标注 dust-containing 类型使用 N100 dust；
- 不覆盖旧图片；
- 带完整绘图日志和输入产品路径。

## 9. 实施阶段

### Phase 1：配置、科学核心和 Unit Gate

- 创建 `code\Chapter5_v2` 冻结目录；
- 建立集中配置；
- 显式读取 immutable OMCAM-v2 priors；
- 实现 Chapter 5 sample adapter；
- 验证 RH/第 2 列查表、`1e9` 单位、N50/N100 和 mixed 守恒；
- 不生产正式产品。

### Phase 2：单样本与 2007-01-01 单日 Gate

- Type 1–7 各选代表样本；
- Type 5/7 覆盖 depol 低于、位于和高于端元范围的诊断样本；
- 输出 component alpha、normalized extinction、volume scale、number factor 和最终 Nd；
- 生成 2007-01-01 候选日产品；
- 与 CCN_v2 的 pre-fss component number 在相同 sample 上对拍；
- 与旧 Chapter 5 只做差异解释，不要求 maxdiff=0。

### Phase 3：单月回归

- 使用 2007-01 冻结日期清单；
- 顺序生成全部可用日产品；
- 复用正式 CLEAR_AIR_STATS；
- pooled aggregation 生成候选月产品；
- 检查类型覆盖率、数量级、分位数、空间相关性和旧/新比值；
- 解释 Marine 与整体单位修复带来的变化。

### Phase 4：正式发布与绘图

- 日/月 Gate 全通过后发布 v2 产品；
- 写 manifest、input inventory、hash 和 `_SUCCESS`；
- 从正式月产品生成新 run 图片；
- 旧 stats-v1/旧 Chapter 5 只标记 `SUPERSEDED_BY_CHAPTER5_V2`，不删除、不覆盖。

### Phase 5：2007-02 独立复验

- 使用相同总控脚本处理 2007-02；
- 自动识别缺失上游日期；
- 验证可续跑、不可重复覆盖和月度日期合同；
- 确认代码不包含 2007-01 硬编码后，才允许扩展到其他月份。

## 10. 强制 Gate

### Gate A：先验和单位

- 先验目录和 manifest 精确匹配冻结版本；
- Marine 参数与最新 AERONET 参数一致；
- RH 列严格递增且范围为 0–99；
- extinction 读取第 2 列且全部有限、正值；
- volume scale conversion = `1e9`；
- 不重复应用 hygroscopic growth factor。

### Gate B：sample science

- Type 1–7 路由正确；
- mixed beta 守恒；
- component alpha、volume 和 number contribution 非负有限；
- dust 使用 N100，其他 component 使用 N50；
- Type 5/7 总值严格等于对应 component 之和；
- Type 5/7 的 component 必须具有相同 `sample_id`，且 `original_type` 分别严格为 5/7；
- 纯 Type 1/2/3/4/6 sample 不得进入 Type 5/7；
- sample-level 组合前后行序、sample_id 和 original_type 必须保持一一对应；
- 与 CCN_v2 相同 sample 的 pre-fss component number 在容差内一致。

### Gate C：日产品

- 仅使用正式 T_all；
- 输入行数、有效行数、各 Type 行数完整记录；
- 5° grid、Day/Night 和月份字段正确；
- component sum 与最终 Nd 守恒；
- candidate Gate 通过前不得发布 `_SUCCESS`。

### Gate D：月产品

- 使用月初冻结且不再变化的日期清单；
- 所有 ready date 均有正式日产品和 `_SUCCESS`；
- CLEAR_AIR_STATS 覆盖日期完全一致；
- monthly sum/count 等于日产逐项总和；
- denominator = aerosol_count + clear_count；
- 无 OOM：逐日流式累加，不合并整月 sample table 到内存。

### Gate E：绘图

- 只读取正式月产品；
- 不重新执行 OMCAM；
- 图题和单位不把 dust N100 错标为统一 N50；
- 图片、日志和输入 inventory 全部位于对应 run。

## 11. 发布和覆盖纪律

- v2 使用新产品类型和新产品键；
- 禁止覆盖旧 `stats-v1`、旧 Chapter 5 月产品和旧图片；
- 正式 v2 日期/月目录存在 `_SUCCESS` 后不可覆盖；
- 重跑写入新的 staging attempt 或新的 run；
- 只有 publisher 可以写正式 product tree；
- publisher 必须先验证目标不存在、所有 Gate PASS、inventory 和 hash 完整。

## 12. 变更纪律

本文件是 Chapter5_v2 后续实施的冻结依据。除非用户明确要求修改计划，后续不得调整：

- 科学定义；
- 目录边界；
- 产品键；
- Type 1–7 组合规则；
- N50/N100 阈值；
- RH/消光查表方法；
- 单位换算；
- clear-air denominator；
- 实施阶段与 Gate 顺序。

实现细节可以为适配 MATLAB、NAS 重试或内存限制而调整，但不得改变上述科学合同。遇到普通实现错误应在当前阶段修复并续跑；只有无法满足冻结科学合同的严重问题才暂停并请求用户决定。
