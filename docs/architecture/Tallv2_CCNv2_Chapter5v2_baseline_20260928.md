# Tallv2 → CCN_v2 / Chapter5_v2 固定基线（2026-09-28）

## 适用范围与状态

本文件记录已经核对的科学输入、调用路径和 2007-01 重跑结果，不修改既有 `docs/CCN_v2/implementation_plan.md`、`docs/Chapter5_v2/implementation_plan.md` 的冻结科学合同。后续月份应使用本文相同的输入版本与计算定义；如需更换参数、QC、分母或时空定义，必须生成新的产品键和审计记录，不能静默改写此基线。

固定共同输入为正式发布的日 `T_all v2`：

`products/tall/t_all_v2/tall__ap-final-v1__era5-real__geotime-v2__qc-v1/YYYY/MM/DD/T_all_YYYYMMDD.mat`

Chapter5_v2 月产品另使用正式日晴空统计：

`products/chapter5/clear_air_stats_v2/clear__ap-final-v1__geotime-v2/YYYY/MM/DD/CLEAR_AIR_STATS_YYYYMMDD.mat`

2007-01 冻结日期清单为 30 个 READY；2007-01-16 因全球 APro 缺失而跳过。30 日的上述两类共同输入均已具有非零 MAT 与 `_SUCCESS`。T_all v2 修正了原生 APro 廓线中心经纬度/时间相对于光学 bin 的错位，也修正了 ERA5 空间索引；不把 TAI/UTC 闰秒约定声称为已经审定。详见 `docs/architecture/tall_geotime_defect_20260928.md`。

## 不可漂移的 OMCAM-v2 先验

先验根目录：

`inputs/priors/ccn_v2/omcam_v2__acp-table4-unitgate-v1/`

| 文件 | SHA-256（2026-09-28 核对） |
|---|---|
| `Parameter_OMCAM_v2.mat` | `A5C581CA5553872EA2AD4F367EDD55327516D2986C92363F2A14A373536E746C` |
| `Extinction_Normalized_v2.mat` | `BB07736C0C1E0CE1C66BC5B5875A4DBF54F29CB36204245D3BEC042D9F84865F` |

`Parameter_OMCAM_v2.mat` 的 `data` 结构沿用旧六类型数组顺序 `[CM, DU, PC, CC, PD, SM]`；运行核心只使用五个物理组分 `[CM, DU, PC, CC, SM]`。逐项核对后，五组分的 10 个粒径/折射率数组字段与 `code/CCN_v2/config/ccn_v2_config.m` 完全一致（数值容差 `1e-9`）。其中最新版 Marine 明确为：

| 参数 | Fine | Coarse |
|---|---:|---:|
| 体积分数 | 0.14 | 0.86 |
| 平均**半径** µm | 0.1137 | 1.8756 |
| 几何标准差 | 1.6487 | 2.0544 |
| 532 nm 折射率实部 | 1.5478 | 1.4108 |
| 532 nm 折射率虚部 | 0.0053 | 0 |

`Extinction_Normalized_v2.mat` 的 `Extinction_N` 对 CM/DU/PC/CC/SM 各有 100×2 表；第 1 列逐行为 RH `0:99`，第 2 列全为正且有限。`runs/ccn/run_ccn_v2_20260921_001/reports/unit_gate_v2.csv` 的五个组分最终均为 `pass=1`。同一 run 下更早的 `unit_gate_smoke.csv` / `unit_gate_full.csv` 含有失败结果，是修复前诊断，不是本基线通过依据。

### 与论文原文的逐项对照

原文：Choudhury et al., ACP 2022, Table 3/4（https://acp.copernicus.org/articles/22/7143/2022/）；Choudhury and Tesche, AMT 2022, OMCAM 算法及 Eq. 8（https://amt.copernicus.org/articles/15/639/2022/）；Choudhury and Tesche, ESSD 2023, 全球产品方法与平均定义（https://essd.copernicus.org/articles/15/3747/2023/）。下面区分“论文参数相符”和“全产品严格复刻”，二者不是同一个结论。

| 检查项 | 论文 | 本基线 | 结论 |
|---|---|---|---|
| Marine AERONET 双峰粒径分布与 532 nm 复折射率 | ACP Table 3 的 Marine (AERONET)：细/粗 `v=0.14/0.86`、`mu=0.1137/1.8756 µm`、`sigma=1.6487/2.0544`、`mr=1.5478/1.4108`、`mi=0.0053/0` | config 与 Parameter MAT 同值 | 精确一致 |
| DU/PC/CC/SM 双峰和折射率 | ACP Table 3；论文有 3–4 位小数的显示舍入 | 五组分 config 与落盘 Parameter MAT 精确一致；相对于 Table 3 是显示精度内一致 | 一致；非逐字字符串相等 |
| 形状与吸湿性 | AMT/ACP：dust spheroid，其他 sphere；dust 非吸湿；marine κ=0.7，continental/smoke κ=0.3 | config 同值，先验 manifest 明示 Marine sphere / Dust spheroid | 方法/配置一致 |
| Mixed Type 5/7 | AMT/ESSD：退偏端元 0.05/0.31，先拆 β 再用 Dust/PC/Marine lidar ratio 44/70/23 sr 求分量消光 | `split_mixed_dust` 与 `compute_ccn_sample_contributions_v2` 同样顺序；同一样本内加和 | 一致 |
| 粒子数阈值 | AMT/ESSD：dust N100，其他物理组分 N50 | dust 下限 0.10 µm、其他 0.05 µm，上限 15 µm | 一致 |
| 过饱和度系数 | ESSD：`n_CCN=f_ss*n_j,dry`；`1/1.35/1.7` 对应 0.15–0.20%、0.25%、0.40% | config 固定 0.20%、0.25%、0.40% 及上述系数 | 一致于论文给定区间；0.20% 是首档标称点 |
| 水平/垂直月网格 | ESSD：2°×5°、60 m、月度 | 2°×5°、原生 0–8 km 133 层，月度按日 sum/count 池化 | 网格主定义一致 |
| RH 来源及 QC | ESSD 使用 Level-2 辅助 GDAS RH、CAD/extQC/不确定度/MLE/云等完整筛选 | ERA5 RH；上游 T_all 仅项目 aerosol-valid QC，缺论文全部 QC 字段 | 不一致，禁止声称 ESSD strict reproduction |
| CCN 均值分母 | ESSD Eq. 4 为 `Σ n_CCN / (N_a + N_ca)` | `Σ n_CCN / N_a`，无 clear-air bin | 不一致；本产品是有气溶胶条件均值 |

ACP Table 4（单位 `Mm cm^-3`）给出 modified marine `21.2077`、dust N100 `11.0847`、PC `24.931`、CC `3.598`、smoke `21.9948`。最终 `unit_gate_v2.csv` 的相应结果为 `21.3923 / 11.1061 / 24.9565 / 3.6008 / 21.9872`，相对差分别约 `0.87% / 0.19% / 0.10% / 0.08% / 0.03%`，五类均按冻结阈值 PASS。该 Gate 验证了单位和数量级，但不等于对 MOPSMAP 所有 RH 点逐点复现论文的散射计算；RH 表是本项目重新生成并已落盘的先验，论文未逐点公布 100 个数值用于严格对拍。

Chapter5_v2 **共用上述组分反演物理核心**，因此上表关于先验、RH 查表、mixed 拆分和 N50/N100 的结论也适用于它；但 Chapter5 的七个原始 Type、5°×5° 昼夜图、≤10 km 截断及 `N_a+N_ca` 分母是本项目 Chapter 5 产品定义，不能当成 ESSD 2023 的 2°×5° 五组分三维产品。其晴空分母形式与 ESSD Eq. 4 相似，不表示上游 QC、RH 和类别语义均相同。

对照旧 `inputs/priors/Parameter_Particle_CALISPO.mat`，其 Marine 细/粗体积分数为 `0.025/0.975`、半径为 `0.15/1.216 µm`，**不是**这里冻结的新版 Marine。后续不能因为旧文件仍存在就将其视为本基线输入。

## 实际运行调用链

2007-01 Tallv2 下游由 `code/batch/start_Tallv2_month_downstream.ps1` 和 `code/batch/run_Tallv2_month_downstream.m` 按 CCN → Chapter5 → Chapter4 串行控制。本节只冻结 CCN_v2 与 Chapter5_v2；Chapter4 是独立遗留反演支路，不属于共同 OMCAM-v2 基线。

### CCN_v2

`T_all v2` → `code/CCN_v2/producers/build_ccn_grid_day_v2.m`（显式传入上述先验根目录，读取 `Extinction_Normalized_v2.mat`）→ `code/CCN_v2/science_core/compute_ccn_sample_contributions_v2.m` → `ccn_v2_config.m` 中的五组分最新版参数 → 2°×5°×133 层日 sum/count → `build_ccn_grid_month_v2.m` 池化日 sum/count → 正式月产品 → 只读月产品绘图。

运行时的粒径/折射率参数来自 `ccn_v2_config.m`；`Parameter_OMCAM_v2.mat` 是落盘、经过逐项对照的同一先验记录，**不是该逐样本函数当前直接 `load` 的运行文件**。不可把“参数 MAT 存在”等同于“运行代码已读取它”；两者数值一致性是本次单独检查的结果。

Type 5 在原始同一 bin 内拆为 dust+PC，Type 7 拆为 dust+marine。退偏振端元为 0.05/0.31，dust/PC/marine lidar ratio 为 44/70/23 sr。dust 数积分下限 0.10 µm（N100），其余 0.05 µm（N50）；采用 RH 插值的归一化消光和通过单位 Gate 的 `1e9` 体积尺度换算。三档过饱和度倍数为 1/1.35/1.70。五组分共用一个有效气溶胶样本分母；无晴空样本进入 CCN 均值分母。因此本产品不能称为 ESSD 2023 严格逐字段复刻。

本次正式产品键：`ccnv2__tall-v2-geotime__era5-rh__omcam-v2__grid2x5-z60`。2007-01 的 30 个日目录和正式 `CCN_GRID_V2_MONTH_200701.mat` 已发布，图片及垂直 CSV 位于 `runs/ccn/run_200701_Tallv2_001/plots/ccn_v2/200701/`。总控进度日志记录 CCN `PASS` 于 2026-09-28 10:10（Asia/Shanghai）。

### Chapter5_v2

`T_all v2` → `code/Chapter5_v2/producers/build_calipso_stats_ch5_v2_day.m` → `chapter5_v2_config.m` 明确读取同一先验根目录中的 `Extinction_Normalized_v2.mat` → `compute_chapter5_sample_contributions_v2.m` 调用 CCN_v2 的 `compute_ccn_sample_contributions_v2.m` 获取乘过饱和度系数之前的五组分 N50/N100 → 同一 `sample_id` 与 `original_type` 内组合七 Type → 5°×5°、Day/Night 的日 `CALIPSO_STATS_CH5_V2` → 结合正式晴空统计池化月 `CHAPTER5_MAP_STATS_V2` → 绘图。

Type 5 的样本值是 dust N100 + PC N50；Type 7 是 dust N100 + marine N50。只允许同一个原始样本的两个组分相加；不得把已经空间聚合的 CCN dust 图与 marine 图相加恢复 Type 7。Chapter5 不使用 CCN 的 `fss`；月均值分母为有效气溶胶数 + 晴空数。因此 Chapter5 图也不能笼统标称七类全为 N50。

本次正式日产品键：`stats-ch5v2__tall-v2-geotime__era5-rh__omcam-v2__grid5deg__stats-v2`。月产品键：`ch5map__stats-ch5v2-tall-v2-geotime__clear-v2__grid5deg__z10km__map-v2`。2007-01 的 30 个日产品、月产品和 `runs/chapter5/run_200701_Tallv2_001/plots/chapter5/monthly/Figure_5_1.png` 已完成；总控日志记录 Chapter5 `PASS` 于 2026-09-28 11:17（Asia/Shanghai）。

## 与 Chapter4 的边界及后续复核

当前 Chapter4 Tallv2 运行虽直读上述 T_all v2，但其 `ARONET_CALIPSO_Fast_Collocation.m` 默认加载旧 `inputs/priors/Parameter_Particle_CALISPO.mat` 与 `Extinction_Normalized.mat`，并调用旧 `Fun_CALIPSO_Calculation_dVdlnr_dNdlnr_Nd_Consider_Hyg_Integral.m`。本基线不声称 Chapter4 已使用新版先验或与 CCN_v2/Chapter5_v2 的粒径谱定义一致。若未来改第四章，必须单独核对旧六类型接口、湿谱、RH 查表和数值 Gate，不得静默变更本文件冻结的两条生产线。

重新生产时至少检查：正式 T_all v2 `_SUCCESS`、日期冻结清单、先验两文件 SHA-256、配置参数逐项相等、最终 `unit_gate_v2.csv` 五类 PASS、各日 Gate 与 `_SUCCESS`、月 pooled sum/count 与冻结日期一致。任何一项不同应停止发布并另立版本。

## 本次串行运行结束记录

`runs/produce/run_200701_Tallv2_downstream_001/logs/progress.log` 最终为 `PASS ccn`、`PASS chapter5`、`PASS chapter4`、`ALL_TALLV2_MONTH_DOWNSTREAM_COMPLETE`；Chapter4 于 2026-09-28 12:52:41（Asia/Shanghai）结束，未遗留本任务 MATLAB 进程。其匹配库和柱积分库均为非零 MAT，`runs/chapter4/run_200701_Tallv2_001/plots/chapter4/` 下六张 Figure 4 PNG 均非零，launcher `.err.log` 为 0 字节。

这个运行完成标记仅证明当前脚本成功执行和产物落盘；Chapter4 的旧微物理反演曾记录 `Inf or NaN value encountered` 数值积分警告，且读取旧先验，不属于这里冻结的 CCN_v2/Chapter5_v2 科学基线。不可将其解释为 Chapter4 已通过新版 OMCAM 数值一致性 Gate。
