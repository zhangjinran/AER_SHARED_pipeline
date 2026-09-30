# VSD 模块分步计划

状态：已开始实施；五组分先验已核验/转移、数学核心与真实 APRO+ERA5 小块 Gate 已通过；**2007-01-01 完整单日产品已发布并通过逐轨道契约 Gate**。将**论文规定**、**旧基线只读证据**与**实测进度**分开。

## 1. 三篇论文的科学约束

| 本地论文 | 必须继承的依据 | 与其他论文/本项目的边界 |
| --- | --- | --- |
| [AMT 2022](../inference/CCN/amt-2022-Choudhury-Estimating%20CCN%20from%20CALIPSO(1).pdf)，§3.1–3.4，印刷页 642–643 | 双峰归一化体积粒径谱（NVSD）、`α=V_t α_n`、κ 吸湿增长、混合尘/非尘先拆后分别反演 | 将先验作湿增长后计算湿光学消光，最终缩放干 NVSD |
| [ACP 2022](../inference/CCN/acp-22-Choudhury-Evaluation%20of%20aerosol%20number%20concentration%20from%20CALIPSO(1).pdf)，§2.3.2–2.3.3、表 3–4，印刷页 7146–7148 | Marine AERONET 新参数、五组分折射率、干态数浓度/消光单位因子 | 用 RH 光学增长因子将**环境消光**修正为干消光；Marine AERONET 原模型为环境态，论文假定 RH=70% 转干态 |
| [ESSD 2023](../inference/CCN/essd-2023-Choudhury%20Global%20CCN%20from%20CALIPSO.pdf)，§2.3、§3.1、表 1、附录表 A1，PDF 页 3–7、20、22 | 全球产品采用 Marine AERONET、逐 bin 质量筛选、混合型拆分和干消光修正；表 A1 提供精细双峰参数 | 论文全球月产品**不是**本项目的 bin 级 VSD MAT，不可声称逐字段复刻 |

三篇论文的湿度处理位置不同，不能同时“湿增长先验”和“环境消光除增长因子”而双重修正。新 VSD **采用 ACP/ESSD 的干消光修正路径，正式保存干态、按半径定义的体积粒径谱，不保存湿谱**；与 AMT 路径的数值等价性仍须以多类型、多 RH 的 Gate 验证。

## 2. 第一实施动作：正确先验的核验与转移

### 2.1 已核验并转移的唯一先验

历史源目录：`F:\AER_SHARED_PIPELINE\inputs\priors\ccn_v2\omcam_v2__acp-table4-unitgate-v1\`。`manifest.txt` 标记 `schema=omcam-v2`、`unit_gate=PASS`、Marine sphere、Dust spheroid、RH `0:99`。

| 文件 | 实际 MAT 内容 | SHA-256 |
| --- | --- | --- |
| `Parameter_OMCAM_v2.mat` | `data`：双峰体积分数、平均**半径**、GSD、532 nm 复折射率。是生成 NVSD 的**参数源**，不是逐半径采样好的谱 | `A5C581CA5553872EA2AD4F367EDD55327516D2986C92363F2A14A373536E746C` |
| `Extinction_Normalized_v2.mat` | `Extinction_N.CM/DU/PC/CC/SM`：各 `100×2`，列为 RH 0…99 与绝对 `α_n(RH)`；还含旧 `PD` 行，不得将其当新混合组分 | `BB07736C0C1E0CE1C66BC5B5875A4DBF54F29CB36204245D3BEC042D9F84865F` |

参数代码：`F:\AER_SHARED_PIPELINE\code\utils\ccn\ccnv2\config\ccn_v2_config.m`。光学表生成代码：`...\priors\build_component_optical_prior_v2.m`，使用 MOPSMAP、532 nm、球/尘椭球、κ 和整数 RH。组装代码：`...\priors\assemble_omcam_v2_prior_candidate.m`。旧数值证据：`F:\AER_SHARED_PIPELINE\runs\ccn\run_ccn_v2_20260921_001\reports\unit_gate_v2.csv`。这些是来源引用；新代码不得硬编码历史路径。

### 2.2 “最新”的具体参数证据

下表 `ν` 为体积分数、`µ` 为几何平均**半径（µm）**、`σ` 为几何标准差；复折射率对应 **532 nm**。NVSD 值对 ESSD 附录表 A1，折射率对 ACP 表 3，历史配置及实际 MAT 数组逐项核验。κ/形状来自 AMT §3.1–3.2 和 ACP §2.3.3。

| 组分 | `ν_f/ν_c` | `µ_f/µ_c` µm | `σ_f/σ_c` | `m_r,f/m_r,c` | `m_i,f/m_i,c` | κ/形状 |
| --- | --- | --- | --- | --- | --- | --- |
| Marine AERONET | 0.14/0.86 | 0.1137/1.8756 | 1.6487/2.0544 | 1.5478/1.4108 | 0.0053/0 | 0.7/球 |
| Dust | 0.223/0.777 | 0.1165/2.8329 | 1.4813/1.9078 | 1.414/1.414 | 0.0036/0.0036 | 0/椭球 |
| Polluted continental | 0.531/0.469 | 0.1577/3.547 | 1.5257/2.065 | 1.404/1.404 | 0.0063/0.0063 | 0.3/球 |
| Clean continental | 0.050/0.950 | 0.20556/2.6334 | 1.61/1.8987 | 1.380/1.455 | 0.0001/0.0034 | 0.3/球 |
| Elevated smoke | 0.329/0.671 | 0.1436/3.726 | 1.5624/2.1426 | 1.517/1.517 | 0.0234/0.0234 | 0.3/球 |

ACP 表 3 对 Dust/PC/CC/Smoke 的部分粒径参数四舍五入，ESSD 表 A1 与历史配置更精细。`Parameter_OMCAM_v2.mat` 第 5 行还保留旧 `PD` 参数；新方案混合型应拆成两个物理组分，不复用此行。

旧 `unit_gate_v2.csv` 在 RH=0 与 ACP 表 4 比较数浓度/消光转换因子（单位 `Mm·cm⁻³`）：Marine `21.2077→21.3923`（0.87%）；Dust 的 **n100** `11.0847→11.1061`（0.19%）；PC `24.9310→24.9565`（0.10%）；CC `3.5980→3.6008`（0.08%）；Smoke `21.9948→21.9872`（0.03%）。这是单位与先验的单点 Gate，**不是**全球结果精度证明，也不能把 Dust n100 说成 n50。

### 2.3 已执行的转移与仍待验证内容

两份必要 MAT 已转移到唯一目录 `F:\AER_STRUCTURE_PIPLINE\product\priors\vsd`；源/目标 SHA-256 分别保持 `A5C581CA...536E746C` 与 `BB07736C...D3BEC042D9F84865F` 完全一致。未复制旧 `Extinction_Normalized.mat`，也未把旧 PD 单行用作新混合先验。参数式 NVSD 与 `α_n(RH)` 已由新代码读取并 Gate。新 RH 光学表未重算；其来源是已完成旧 CCN_v2 MOPSMAP 单位 Gate 的正式表。仍需整日 APRO/ERA5 产品 Gate。

## 3. APRO 与 ERA5 输入：真实位置及样例结构

| 输入 | 只读实测 | 实现前还需核验 |
| --- | --- | --- |
| 全球 APRO 日 MAT | `Z:\CALIPSO_MAT_FINAL\CHAPTER5_AP\05kmAP\2007\2007_01_01.mat`，142,260,084 B；v7.3 HDF5，`day.files` 为 `1×29` 轨道条目。**MATLAB 实际读取**首条轨道的消光、后向散射、退偏为 `[3728,399]`；AVD `[3728,399,2]`；经纬度和 `Profile_Time` 各 `[3728,3]`；高度轴 `[399,1]`；保留 `filename` | 旧草稿的 `[bin,profile,plane]` 是错误的维度假设，已按实际 `[profile,bin,plane]` 改正。`399`、`3728` 只是样例，不能全局写死。 |
| ERA5 小时 MAT | `Z:\ERA5\mat\2007\01\01\ERA5_20070101_00.mat`；`ERA5.RH/height` 为 `1440×721×37`，`lon` 1440、`lat` 721、`lev` 37，另有 `time`；日目录按 `ERA5_yyyymmdd_HH.mat` | 用实际轴检查经纬方向、时间基准、高度与 RH 单位、缺失/非单调剖面、跨日临近小时，不以 shape 推断。 |

旧根路径来自 `F:\AER_SHARED_PIPELINE\code\utils\shared\config\data_roots.m`。旧 `read_calipso_apro_core.m` 表明 MAT 为 `[bin,profile]`、AVD `[plane,bin,profile]`。旧 `build_calipso_step1_day.m` 使用 profile 中心经纬/时间、1993-01-01 秒数转 UTC、399 高度轴、ERA5 最近小时和高度插值；是可审计参考，不是新实现已验证合同。其 T_all 仅保留 `type>0` 且 `Ext>0/Back>0/Depol>=0` 的 bin，**不能**充当新 VSD 全 bin 输入或验证基准。

## 4. 拟定 VSD 物理计算

对五个纯物理组分，按干半径 `r`（µm）使用单位总体积双峰谱：

`q_t(r)=Σ_{i=f,c} ν_{t,i}/[√(2π)lnσ_{t,i}] · exp{−[ln(r/µ_{t,i})]²/[2(lnσ_{t,i})²]}`，其中 `q=dV_n/dlnr`。AMT Eq. (6) 给出 `α=V_t α_n`。MOPSMAP 按 532 nm 折射率、组分形状和 κ 计算 `α_n,t(RH)`，不能用论文转换因子手填整张表。AMT Eq. (7) 的**半径**增长比为 `g_r(RH)=[1+κ RH/(100−RH)]^(1/3)`；**光学**增长因子 `g_α,t(RH)=α_n,t(RH)/α_n,t(0)`，二者不同。尘 κ=0。

按 ACP/ESSD 路径：`α_dry,t=α_ambient,t/g_α,t(RH)`，`V_t=α_dry,t/α_n,t(0)`，`VSD_t(r)=V_t q_t(r)`。两次除法不可再叠加对先验的湿增长。**统一半径轴**只指：如需数值积分或比较两组分，必须在相同、单位为 µm 的干半径 `r` 上评价参数式谱；不要求每个 bin 存一条离散半径数组。`dV/dlnr` 的目标物理单位按半径 µm、数浓度 cm⁻³ 表述为 `µm³ cm⁻³`（`dlnr` 无量纲）；论文给出定义公式但并未在上述段落显式规定本项目 MAT 存储单位，必须通过 MOPSMAP 归一化、`α` 单位和数浓度积分 Gate 证明。旧代码用显式 `1e9` 体积尺度换算，新实现不得不经单位审计照抄。`type>0` 的 bin 如 RH/消光/必要数值输入无效而反演失败，按用户决定**不写入 VSD 日产品**，在运行日志中统计丢弃数量和原因，不伪装为 `type=0`；`type=0` 的无气溶胶 bin 不需反演且继续保留。

AMT 的可选写法是用 `α_ambient/α_n(RH)` 直接缩放干 NVSD。若两表的归一化和单位相同，数值可能等价，但必须在 RH=0、中、高以及各类型上 Gate，而不能仅凭代数断言代码实现正确。

## 5. 单个 bin 到日 MAT 的拟定步骤

1. 逐轨道读取 `day.files`；保存原 `filename` 为 `source_hdf`，`profile_id` 是**该 HDF 中**的廓线序号，`sample_id` 是该廓线内的垂直 bin 序号；三元键不可因日合并重新编号，也不能仅靠经纬度识别廓线。
2. 从 APRO 的 profile 中心经纬/时间及高度轴生成每个 bin 的经纬、时间与**中心点高度**。先审计 `3×profile` 的中心列、时间纪元/单位和高度轴顺序，再按样例对原 MAT/HDF 逐项核对。
3. 解码 AVD 的 feature type/subtype；无气溶胶 bin **仍生成记录、`type=0`**。多类别 bin 严格取实测 `[profile,bin,2]` 中顺序第一个 plane，不投票、不融合。`type=0` 记录采用参数式零谱（缩放系数为 0）。如果 feature=3 但 subtype=0，这是**未分类气溶胶**，不是晴空；按反演无效丢弃并计数，不能伪装成 `type=0`。
4. **不应用 ESSD 的 CAD、extQC、不确定度、MLE 等 QC 筛选**，因为现有 APRO MAT 没有这些字段且用户明确决定不做。论文与本项目的差异要在文档和产品说明中如实列出。仅对实际计算所需数值作可计算性判断；`type>0` 但反演失败的 bin **删除该 bin 的 VSD 记录**并记录原因，不能改写成 `type=0`。
5. 由真实 ERA5 经纬/时间/高度轴匹配每个可反演 bin 的 RH，并记录覆盖率及无效原因。纯类型使用相应先验；Type 5（polluted dust）拆 Dust+PC，Type 7（dusty marine）拆 Dust+Marine。AMT Eq. (8)：`β_d/β_p=[(δ_p−δ_nd)(1+δ_d)]/[(δ_d−δ_nd)(1+δ_p)]`，`δ_d=0.31`、`δ_nd=0.05`，端点按纯组分；`β_nd=β_p−β_d`。再分别以 Dust 44、PC 70、Marine 23 的 lidar ratio 得各自消光。不能使用旧 `PD` 单行参数直接反演混合型。负组分、异常退偏和不守恒须进 Gate，不擅自裁剪。
6. 对每个组分独立进行 RH 查表、消光修正、VSD 缩放。原始 Type 5/7 的**一个物理 bin 输出两个组分记录**，而不是相加成一个谱，也不是两个新的 APRO 物理 bin。两条记录均保留原 `type=5` 或 `7`、同一个 `source_hdf/profile_id/sample_id`；另增一个明确的 `component` 字段：Type 5 对应 `dust` 和 `polluted_continental`，Type 7 对应 `dust` 和 `marine`。因此唯一键是 `(source_hdf, profile_id, sample_id, component)`；仅前三项故意重复，表示来自同一个原始 bin。纯类型也填写对应 component，`type=0` 填 `none`。VSD 用参数式组分先验标识加缩放系数表达；详细 MAT 变量组织在编码前冻结。分量为零时可保留零缩放组分记录，以维持两组分关系；真正计算失败时删除该原 bin 的两个组分记录并记录原因。
7. 日产品覆盖当天所有相关轨道的**成功反演气溶胶 bin 和全部无气溶胶 bin**；失败的气溶胶 bin 不写入。输出一个 MAT，日志统计原始轨道/廓线/bin、`type=0`、成功/失败、Type 5/7 拆分前后记录数及丢弃原因。按轨道/受控块处理，避免盲目展开全日密集谱。

## 6. Gate 与实施顺序

- **先验 Gate**：五组分参数逐项对论文，RH 0…99 表每行有限且正，Dust 不随 RH 变化；ACP 表 4 单位因子对拍；转移前后文件哈希一致，新管线不依赖旧目录运行。
- **结构 Gate**：抽单轨道、单日；核对 `type=0` 全部保留、失败气溶胶 bin 的丢弃清单、Type 5/7 每个成功物理 bin 恰有两条 component 记录。唯一键为 `(source_hdf,profile_id,sample_id,component)`；经纬、时间、高度和前三项原始索引可回定位。
- **科学 Gate**：纯 Marine/Dust/PC/CC/Smoke、Type 5/7 和若干 RH 点，检查 `β_d+β_nd=β_p`、消光与谱光学闭合、单位、积分、异常值。不把科学无效当晴空零谱。
- **运行 Gate**：正式路径由配置传入；逐日期/轨道日志、明确失败；单日候选通过后才发布。先验、VSD、日志、测试分别进入 `product/`、`product/`、`run/.../logs/`、`run/test/.../result/`。无逐日复制脚本，无自动修改旧项目。

截至 2026-09-30：五组分先验已转移并通过参数/单位 Gate；真实 APRO+ERA5 首轨道前 100 廓线块 Gate 通过；正式 `product/vsd/2007/01/01/VSD_20070101.mat` 已处理 29 轨道并通过独立逐轨道契约 Gate。原始 45,900,960 bin、非气溶胶 44,649,600、有效气溶胶 1,023,598、无效气溶胶 227,762、混合型 212,224，最终 45,885,422 条组分记录；等式 `原始 bin − 无效气溶胶 + 混合型 = 输出记录` 成立。该日 MAT 约 401 MB。**只完成这一天，未验证月度生产、跨日期覆盖、与论文全球产品的逐像元对拍**；下一步先扩展多日 Gate，再设计月批处理。

## 7. 已由用户裁决及仍待技术核验

用户已裁决：只保存干谱；不做缺失 ESSD QC；AVD 第一 plane；`type=0` 表示无气溶胶并保留；反演失败的气溶胶 bin 删除；Type 5/7 拆为同源两组分记录；沿用参数式 NVSD，不保存每 bin 的完整离散谱。实现采用列式 struct：每行一条逻辑记录，`source_hdf` 使用 categorical 列节省空间，`component_id` 区分同源 Type5/7 两条记录，原 `type` 保持 5/7 不变。已发布 2007-01-01 正式日产品，未重跑 MOPSMAP、未进行 Git 操作。
