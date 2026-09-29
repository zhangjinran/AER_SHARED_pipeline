# `code/` 迁移目录与 Gate（2026-09-28）

本方案只改变源码位置和调用路径，不改变科学公式、先验、正式产品键或正式日期目录。每支路迁移后先以 2007-01-01 做独立 Gate，通过后再迁移下一支路。

```text
code/
  run/{tall,ccn,chapter5,chapter4,aod,shared,legacy}/
  utils/{tall,ccn,chapter5,chapter4,aod,shared,legacy}/
  test/{tall,ccn,chapter5,chapter4,aod,legacy}/
```

章节目录不含版本号。现行 v2 实现位于章节内以版本命名的子目录，如 `code/run/chapter5/chapter5v2/`、`code/utils/ccn/ccnv2/`、`code/test/tall/tallv2/`。`legacy/` 仅存放停用但需追溯的历史代码；不加入现行生产 MATLAB 路径，也不作为当前生产入口。

## 迁移顺序

1. Tallv2 与 ClearAir v2 共同上游。
2. CCN_v2。
3. Chapter5_v2。
4. Chapter4 当前版（输入 Tallv2，微物理仍为旧版）。
5. AOD v2。
6. 旧代码隔离至 `legacy/`，消除同名函数遮蔽。

`run/` 只放可直接启动的入口；`utils/` 放配置、科学核心、生产器、发布器与绘图实现；`test/` 放 Gate、审计与诊断。先验 MAT 的唯一正式位置保持 `inputs/priors/`。`code/priors/先验数据/` 的三个同名 MAT 已核对与正式先验 SHA-256 相同；原位置的重复副本已移入 `code/test/legacy/duplicate_priors/`，不在生产路径上，未新增副本。

## 2007-01-01 最小 Gate

各阶段候选产物只能写入对应产品键下 `test/<migration-id>/2007/01/01/`，与正式 `2007/01/01/` 隔离；日志写入 `runs/produce/` 下单独的迁移 run。先核对新入口与所有依赖的 `which(...)` 解析路径，再运行一天。逐阶段与已发布的 2007-01-01 产品核对：变量名、字段、维度、样本/轨道数、关键数值与 NaN 掩码；仅路径或元数据字符串允许预先记录的差别。Gate 报告记录源/候选路径、先验哈希、检查项、差异和 PASS/FAIL。未通过不得改正式产品、不得进入下一支路。测试完成后不把大 MAT 加入 Git。

历史代码可能通过 `mfilename('fullpath')` 推导根路径，且启动器含 `code/CCN_v2`、`code/root_scripts` 等硬编码路径；迁移时必须一并修正。不要将 `addpath(genpath(code))` 用于生产，以免 `legacy/` 中同名函数遮蔽现行实现。

## 2026-09-28 单日 Gate 实测记录

迁移测试 run：`runs/produce/run_code_layout_20260928_001/`。以下测试均只写入相应正式产品键下的 `test/code_layout_*_20260928_001/2007/01/01/`，不改正式日期产品。

| 支路 | 对照内容 | 结果 |
| --- | --- | --- |
| Tallv2 | 882,444 行，12 个表字段及 UserData，与正式日 MAT `isequaln` | PASS |
| ClearAir v2 | 29 条已处理轨道，`CLEAR_STATS` 和 `processed_files` 与正式日 MAT `isequaln` | PASS |
| CCN_v2 | `sum_component`、`sum_total`、`sample_count`、`meta` 与正式日 MAT `isequaln` | PASS |
| Chapter5_v2 | `CALIPSO_STATS_CH5_V2` 整体与正式日 MAT `isequaln`，755,682 个有效行 | PASS |
| AOD v2 | `AOD_PROFILE` 和 `AOD_GRID` 与正式日 MAT `isequaln`；115,040 条廓线、58,781 条有效、1,277 个占用格点 | PASS |
| Chapter4 当前版 | Matched_DB、Column_DB 与旧单日 Tallv2 run `isequaln`；6 张图均非空 | PASS |

上述 PASS 仅证明第一轮已迁移的单日路径和结果；不能代替归档后的第二轮 Gate。整理改动仍未提交；共享目录中的 `load.m` 是现有 NAS 重试包装器，其与 MATLAB 内置函数同名，需要在 Gate 中显式核对 `which`，且不得把整个 `code/` 递归加入生产路径。

## 后续决定与归档后回归

用户明确规定：只做 2007-01-01 日 Gate，不做月度验证；提交与推送须等用户明确指令。已删除本地临时整理分支，当前工作在 `main` 的未提交工作区，尚未提交或推送整理改动。

原 `code/root_scripts`、旧版 adapters/consumers/producers/publishers、旧 batch 等已移至 `code/utils/legacy/` 或 `code/run/legacy/`；活动的 `code/functions`、`code/config`、`code/common` 已移至 `code/utils/shared/`，相关现行入口同步更新。第二轮 Gate 使用新的 `test/code_layout_*_20260928_002/2007/01/01/` 目录，运行入口为 `code/test/shared/run_postarchive_day_gates_20070101.m`，执行前及每阶段后检查 MATLAB path 不含旧顶层或 `legacy`，并核对关键函数的 `which` 路径。第二轮 Gate 的最终状态以该 run 的日志和各产品的 `gate_report.txt` 为准，不能因进程启动而记为 PASS。

第二轮实测结果：Tallv2、ClearAir v2、CCN_v2、Chapter5_v2、AOD v2 均 PASS；Chapter4 的 6 张图及 Matched_DB/Column_DB 也与旧单日 Tallv2 run `isequaln`，PASS。Chapter4 旧绘图脚本的 `clearvars` 清除了 Gate 编排器的 `code_root` 局部变量，导致绘图完成后总脚本在最终路径断言处退出；仅测试编排受影响，未重算前面各阶段。已在编排器中重建该变量，并以独立 MATLAB 进程补做 Chapter4 数据库对照，日志 `runs/produce/run_code_layout_postarchive_20260928_002/logs/postarchive_ch4_finalize_matlab.log` 记录最终 PASS。`code/utils/shared/current/load.m` 是保留的 NAS 重试包装器，MATLAB 会提示其与内置 `load` 同名；Gate 的 `which` 已确认使用此指定文件。

Git 索引中的 `code/` 顶层目前仅有 `run/`、`utils/`、`test/`。文件系统上仍可能看见一些空旧目录（Git 不跟踪空目录）；旧的先验重复 MAT 已移入 `code/test/legacy/duplicate_priors/`，正式 `inputs/priors/` 未改。此次整理仍是未提交工作区变更，未提交、未推送。

## 2026-09-29 实体目录清理与第三轮完整日 Gate

复核 `code/` 的实际文件系统后，确认顶层 `ccn/`、`chapter4/`、`chapter5/`、`Chapter5_v2/`、`pipeline/`、`priors/`、`products/`、`shared/` 及其下级目录均无文件。逐一移除这些空目录后，实际顶层只剩 `run/`、`test/`、`utils/`；`legacy/` 文件及正式先验未删除。空目录清理不改变 Git 跟踪文件。

第三轮使用全新编号 `20260929_003`，与 `_001`、`_002` 测试产物隔离。先从 2007-01-01 全球 APro 与 ERA5 重新生成 T_all 候选，再从同日原始 APro 生成 CLEAR_AIR_STATS；CCN_v2、Chapter5_v2 均读取**本轮 T_all 候选**。Chapter4 为满足原日产品目录接口，在本轮测试目录建立指向同一候选 MAT 的 NTFS 硬链接和测试专用 `_SUCCESS`，没有复制大 MAT，也没有读取旧测试产品。AOD v2 独立从全球 APro 重新生成廓线和日网格。所有新产物位于各产品目录的 `test/code_layout_*_20260929_003/2007/01/01/`，未覆盖正式日期目录。

| Gate | 第三轮结果 |
| --- | --- |
| T_all v2 | 29 轨道、882,444 行，12 个字段及 UserData 与正式日产品一致；PASS |
| CLEAR_AIR_STATS v2 | 29 轨道，结构与正式日产品一致；PASS |
| CCN_v2 | `sum_component`、`sum_total`、`sample_count` 及除 `meta.source_tall` 外的元数据一致；候选的 `source_tall` 明确指向本轮候选；PASS |
| Chapter5_v2 | 755,682 个有效样本，`grid` 及除 `meta.source_tall` 外的元数据一致；候选的 `source_tall` 明确指向本轮候选；PASS |
| AOD v2 | 115,040 条廓线、58,781 条有效、1,277 个占用格点；新廓线 MAT 与日网格 MAT 均与正式产品一致；PASS |
| Chapter4 当前版 | 从本轮 T_all 候选读取 882,444 行；Matched_DB、Column_DB 与旧单日基线一致，六张新 PNG 非空；PASS |

编排器 `code/test/shared/run_postarchive_day_gates_20070101.m` 因 T_all 构建与下游串行执行，分 `tall`、`downstream` 阶段；本轮在 CCN 与 Chapter5 整体 `isequaln` 断言处发现的唯一差异是新输入路径写入的 `source_tall` 元数据。数值字段重新确认后，通过 `resume_ccn`、`resume_ch5` 阶段接续同一测试编号，不重用旧编号产物，也不重复运行已经完成的重计算。日志位于 `runs/produce/run_code_layout_clean_20260929_003_*_matlab.log`；最终日志有 `POSTARCHIVE_DAY_GATES_20070101_PASS`。MATLAB 路径检查每阶段均为 `POSTARCHIVE_PATH_PASS no_legacy_or_old_top_level`。整理改动目前仍未提交、未推送。

绘图 Gate 后续从这轮日候选另生成 CCN 四张、Chapter5 七类型一张、AOD 两张 PNG，均在对应 `test/code_layout_*_20260929_003/2007/01/01/plots/`，不进入正式产品或 Git。CCN 日图复用日/月同构的 sum/count 绘图器并明确标注单日；Chapter5 测试绘图按月聚合器相同的 `sum(Nd)/(aerosol_count+clear_count)` 规则对本轮一天的 Stats 和 Clear-Air 候选作视图；AOD 使用现有日图绘图器，修正标题计数所用字段为实际产品中的 `profile_count`。最终 `runs/produce/run_code_layout_clean_20260929_003_plots_final_gate.log` 记录 `LAYOUT_PLOT_ALL_PASS`。此绘图 Gate 不表示已生产或验证月产品。
