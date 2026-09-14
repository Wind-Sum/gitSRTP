Real_test：2026-08-29 实测采集脚本与数据
========================================

一、文件夹用途

本文件夹保存 2026 年 8 月 29 日现场实测时使用的 MATLAB 采集脚本、MATLAB 工作区快照和采集结果。这里主要记录硬件控制、VNA 扫频、阵列编码、原始数据和第一阶段通道恢复，不代表已经完成最终 DOA/AoA 定位验证。

二、主要脚本

- MS46322B_B2B_S21_Measurement.m：测量 VNA 与射频链路的 B2B S21 基线。
- OnOff_Localization_Test.m：每次只开启一个阵元，其余阵元设为高衰减，直接测量逐阵元复数通道。
- Hadamard_Localization_Test.m：依次发送 32 组 0°/180° 正交码字，再解码得到逐阵元复数通道。
- REV_Localization_Test.m：逐阵元执行0°、45°、……、315°八个唯一相位及360°闭合重复，保存原始复数S21；前八相位用于复数DFT参考和功率REV，360°用于闭合检查。
- untitled.m：现场形成的临时探索/绘图脚本，不属于正式处理流程。
- matlab_workspace.mat：现场 MATLAB 工作区快照，不替代各结果目录中的正式 Result.mat 和 Checkpoint.mat。

三、结果目录

所有采集结果位于：

    results/

其中包括：

- B2B：射频链路基线；
- Location1—4：相同信源位置下的四个阵列位置，包含 On/Off、Hadamard、REV 数据；
- Location5：阵列位于 Location4，信源位置改变，仅有 On/Off 数据，只适合独立 DOA 分析；
- results 根目录下另有一组未归入 Location 文件夹的 Hadamard 数据，其具体实验场景尚未确认。

四、三种采集方法与四条分析分支

本次实测包含 REV、On/Off、Hadamard 三种采集方法，并形成四条分析分支。Branch 1 与 Branch 4 共用同一份九相位 VNA 复数 S21 原始数据 ZRev；Branch 2 和 Branch 3 来自各自独立的采集。

    ZRev
    ├─Branch 1：复数 DFT → HRevComplex（复数参考）
    └─Branch 4：取 |ZRev|²、丢弃 VNA 相位
                 → 功率 REV → HRevPower（核心验证）

    On/Off独立采集
    └─Branch 2：逐阵元直接测量 → HDirect（直接参考）

    Hadamard独立采集
    └─Branch 3：32组正交码字测量 → 解码 → HElement（编码参考）

| 分支 | 规范输出 | 是否使用 VNA 相位 | 角色 |
|---|---|---:|---|
| Branch 1：复数 DFT | `HRevComplex` | 是 | 与 Branch 4 同源的复数参考 |
| Branch 2：On/Off | `HDirect` | 是 | 逐阵元直接测量参考 |
| Branch 3：Hadamard | `HElement` | 是 | 正交编码测量参考 |
| Branch 4：功率 REV | `HRevPower` | 否 | 项目核心验证分支 |

- ZRevRepeats：各阵元、各频点、各相位状态、各次重复采集的原始复数 S21。
- ZRev：重复采集平均后的九相位复数 S21。
- HRevComplex：使用完整复数 S21 解调得到的阵元复响应，用作参考和诊断。
- HChannel：不同采集脚本为兼容代码设置的内部别名；在 REV 结果中等于 HRevComplex，在 On/Off 结果中等于 HDirect，在 Hadamard 结果中等于 HElement。它不是全局默认分支选择。
- HRevPower：仅使用 |ZRev|² 进行功率 REV 反演得到的归一化阵元复响应 `H/(B+H)`，是项目核心验证分支的输出；它与真实 `H` 只差全阵列公共复标量，足够用于 DOA。
- revDiagnostics：拟合残差、功率有效性、背景条件和 0°/360°闭合误差等质量指标。

CSV 文件导出 HRevComplex、HRevPower 及诊断指标；完整九相位原始序列保存在 REV Result.mat 和 Checkpoint.mat 中。

五、四分支使用原则

- 完整复数 S21 应保留，用于重新处理、故障排查以及检查功率 REV 恢复结果是否合理。
- 四条分支不存在默认选择；各分支的定位脚本必须显式读取自己的规范输出：HRevComplex、HDirect、HElement 或 HRevPower。
- 验证“仅凭幅度/功率恢复相位并定位”时，Branch 4 只能使用 HRevPower，并结合 powerValid 筛选；VNA 测得的相位只能用于离线对照。

注意：2026-08-29 已保存 MAT 中的旧 `HRevPower` 曾使用复数背景场相位，不满足严格隔离定义；原始 `ZRev` 完整保留。`../FourBranchRev/run_four_branch_rev_analysis.m` 会从 `abs(ZRev).^2` 重新计算严格的 `H/(B+H)`，不会覆盖历史 MAT。当前采集脚本已同步修正，后续新测量会直接保存严格结果。
- Branch 1、Branch 2、Branch 3 是三条参考分支，必须与 Branch 4 分开报告，再采用统一指标比较。
- 当前数据已经通过统一DOA/定位算法、三条参考分支和Branch4全相移子集完成最终一致性评价；绝对定位偏差按现有实验系统不确定性边界报告。

六、下游闭环与穷举结果

- 标准四分支处理入口：`../run_closed_loop_analysis.m`；
- 469种复响应方法×11种定位组合入口：`../run_exhaustive_comparison.m`；
- 结果总览：`../EXHAUSTIVE_RESULTS_SUMMARY.md`；
- 5159条逐链结果：`../Localization/output/exhaustive_full_pipeline.csv`。

穷举分析没有改写本目录的历史MAT文件。它从原始`ZRev`重新形成实数功率，并统一抽取4.5--5.5 GHz内21个频点进行全部方法比较。Branch4的466个子集中有7个三观测组合因0°与360°重复而秩不足，已明确标记不可恢复；其余459个Branch4方法与三个参考方法均完成全部11种定位。
