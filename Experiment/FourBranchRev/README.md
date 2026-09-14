# 四分支复响应恢复层

本目录只负责从实测原始量恢复四种规范阵元复响应，并评价响应本身；定位已拆分到 `../Localization/`。

完整闭环可直接运行 `../run_closed_loop_analysis.m`；以下入口用于只重算本层。

```matlab
cd('Experiment/FourBranchRev')
bundle = run_four_branch_rev_analysis;
```

目录职责：

- `Branch1/`：8个唯一相位复数 S21 的一阶 DFT参考；
- `Branch2/`：On/Off 直接逐阵元参考；
- `Branch3/`：Hadamard 正交解码参考；
- `Branch4/`：严格仅从功率恢复 `H/(B+H)` 的验证分支；
- `common/`：冻结元数据、相移调度、最小二乘恢复、响应指标和测试；
- `output/`：跨分支总表、3--9 状态扫描和完整规范响应包。

REV 状态按以下嵌套顺序增加：

```text
0/90/180 -> +270 -> +45 -> +135 -> +225 -> +315 -> +360
```

Branch1和Branch4的正式输出均使用前8个唯一相位。第九次观测360°与0°物理同相，仅作为状态递增试验中的重复观测及闭合一致性检查；因此9次观测对应8个唯一相位。Branch1在3--7状态下使用复谐波最小二乘，8状态使用正式DFT。

响应指标包括公共复标量对齐后的复相干系数、相位 RMSE、复数 NMSE、幅度 NRMSE、幅度相关系数、功率有效率、训练拟合 NMSE 和留出相移预测 NMSE。

公共复标量对齐只允许对全部32阵元共同乘一个复数，用于消除不影响AOA的整体增益和相位零点；不会逐阵元拟合。详细公式与指标解释见`../EXHAUSTIVE_RESULTS_SUMMARY.md`。

全部Branch4观测子集的穷举入口为`run_exhaustive_response_methods.m`。它枚举`C(9,3)+...+C(9,9)=466`种功率REV输入，并与Branch1--3合并为469种复响应方法；为控制文件体积，只缓存统一选定频点上的复响应及所有诊断表。

穷举结果表明，Branch4从3观测增加到9观测时，跨子集有效率中位数由83.48%升至97.62%，对Branch1相干系数中位数由0.703升至0.959，相位RMSE由50.33°降至13.57°。7个同时含0°、360°和仅一个其他相位的三观测组合秩不足，已保留并标记不可恢复。

穷举输出：

- `output/exhaustive_response_methods.csv`：469种方法的编号、相位子集、秩和可恢复性；
- `output/exhaustive_response_agreement.csv`：每种方法在四个位置对四个参考的响应指标；
- `output/exhaustive_response_summary.csv`：逐方法汇总；
- `output/exhaustive_response_cache.mat`：后续5159条定位使用的统一频点响应缓存；
- `output/EXHAUSTIVE_RESPONSE_REPORT.md`：按观测数汇总。
