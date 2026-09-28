# 当前生产基线（2026-09-28）

本文件用于区分“仓库里保存的历史代码”和“现在生产中使用的科学/产品版本”。Git 纳入 `code/` 的文本源码、`docs/` 和 `inputs/priors/` 的已选先验；**纳入版本控制不等于被选为当前生产入口**。`products/`、`runs/`、其他 `inputs/` 原始数据、`report/` 和图像不提交到 Git。当前重构目录前，请先核对所有硬编码路径；不得仅凭源码文件名移动在用入口。

| 支路 | 当前输入与生产身份 | 当前入口/核心 | 状态与边界 |
|---|---|---|---|
| T_all v2 | 全球 Final APro + ERA5，`tall__ap-final-v1__era5-real__geotime-v2__qc-v1` | `code/batch/run_Tallv2_base_month.m` → `code/validation/rebuild_tall_geotime_day.m` → `code/root_scripts/build_calipso_step1_day.m` | 当前共同输入。修正了原生廓线中心经纬度/时间和 ERA5 空间索引；TAI/UTC 闰秒审计仍未完成。|
| CLEAR_AIR_STATS v2 | 全球 Final APro，`clear__ap-final-v1__geotime-v2` | 同一 Tallv2 月总控 → `code/producers/chapter5/build_clear_air_stats_day.m` | Chapter5_v2 的独立晴空计数输入。|
| CCN_v2 | T_all v2 + OMCAM-v2 先验，`ccnv2__tall-v2-geotime__era5-rh__omcam-v2__grid2x5-z60` | `code/CCN_v2/science_core/compute_ccn_sample_contributions_v2.m`、`code/CCN_v2/producers/` | 五物理组分、2°×5°×133 层；月图分母只含有效气溶胶样本，不是 ESSD 严格复刻。|
| Chapter5_v2 | T_all v2 + 同一 OMCAM-v2 核心 + CLEAR_AIR_STATS v2；月产品键 `ch5map__stats-ch5v2-tall-v2-geotime__clear-v2__grid5deg__z10km__map-v2` | `code/Chapter5_v2/science_core/compute_chapter5_sample_contributions_v2.m`、`code/Chapter5_v2/producers/` | 按原始七 Type 组合，5°×5°，分母为气溶胶计数加晴空计数。|
| AOD v2 | **原生全球 APro，不经过 T_all**；`aod-month__global-apro__avd2__profile-pooled__grid5deg-v2` | `code/aod/science_core/integrate_aod_apro_orbit.m`、`code/aod/batch/run_aod_apro_month.m` | 原生整条廓线积分；两个 AVD half-layer 分开处理。|
| AERONET / Chapter4 | 当前读取 T_all v2，但卫星粒径谱反演仍用旧先验和旧函数 | `code/batch/run_chapter4_month.m` → `code/consumers/chapter4/ARONET_CALIPSO_Fast_Collocation.m` → `code/functions/Fun_CALIPSO_Calculation_dVdlnr_dNdlnr_Nd_Consider_Hyg_Integral.m` | **不是 Chapter4_v2 微物理基线**。新先验/共同 OMCAM 湿谱适配尚未实施；Figure 4.4 使用模拟 RH，不能作为物理归因证据。|

正式 OMCAM-v2 先验纳入 Git，位于 `inputs/priors/ccn_v2/omcam_v2__acp-table4-unitgate-v1/`。两文件在 2026-09-28 核验时的 SHA-256：`Parameter_OMCAM_v2.mat` 为 `A5C581CA5553872EA2AD4F367EDD55327516D2986C92363F2A14A373536E746C`；`Extinction_Normalized_v2.mat` 为 `BB07736C0C1E0CE1C66BC5B5875A4DBF54F29CB36204245D3BEC042D9F84865F`。代码里的 Marine 新参数为细/粗体积分数 `0.14/0.86`、平均**半径** `0.1137/1.8756 µm`、几何标准差 `1.6487/2.0544`、532 nm 折射率实部 `1.5478/1.4108`、虚部 `0.0053/0`。完整基线及与论文的边界见 `docs/architecture/Tallv2_CCNv2_Chapter5v2_baseline_20260928.md`。

**T_all v2 的 AVD 分类规则**：读取适配器将 AVD 归一化为 `[profile, altitude, plane]`；`build_calipso_step1_day.m` 只取 `AVD(:,:,1)`。该平面经 `bitand(AVD,7)` 得到 feature type，经 `bitand(bitshift(AVD,-9),7)` 得到 aerosol subtype。第 2 个 AVD half-layer 不参与 T_all 分类；AOD v2 则处理两者。这是当前代码实际行为，不应误画成相同前处理。

2026-09-28 的 2007-01 基线验证：冻结清单 30 个 READY，2007-01-16 缺全球 APro；Tallv2/Clearv2 日双产品均 30/30；CCN_v2、Chapter5_v2 正式日/月产品完成；第四章 Tallv2 下游运行完成但仍是旧微物理；AOD v2 独立完成 30 日日/月积分。详细算法、公式、结果与图片在 `report/0928/0928_四管线算法与结果汇报.md`（不入此源码仓库）。

下一阶段将按 `test/`、`run/`、`utils/` 三类和章节整理 `code/`；本次 Git 提交先冻结**迁移前**的可回溯状态。迁移时必须同步修复路径、在新 run 验证，不能静默改变上述科学定义或覆盖正式产品。
