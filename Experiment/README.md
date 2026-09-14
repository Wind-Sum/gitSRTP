# 实测四分支闭环分析

当前结果、统计口径、指标定义和完整文件索引统一见`EXHAUSTIVE_RESULTS_SUMMARY.md`。

推荐从本目录运行一次性入口：

```matlab
cd('Experiment')
analysis = run_closed_loop_analysis;
```

处理链分为两层：

1. `FourBranchRev/`：由实测数据分别恢复 Branch1--4 阵元复响应，进行四分支响应拟合，并对3--9次相移观测逐级验证；Branch1正式基准为8相位复数DFT，Branch4为8相位功率REV；
2. `Localization/`：消费统一复响应，先计算四个位置的单站 AOA，再遍历 6 个两站、4 个三站和 1 个四站组合，最后完成响应与定位的双闭环验证。

汇总报告：

- `FourBranchRev/output/FOUR_BRANCH_RESPONSE_REPORT.md`
- `Localization/output/LOCALIZATION_REPORT.md`
- `EXHAUSTIVE_RESULTS_SUMMARY.md`

分支自己的复响应结果和定位结果分别保存在两层目录下的 `Branch1/`、`Branch2/`、`Branch3/`、`Branch4/` 中。

## 469×11穷举比较

```matlab
cd('Experiment')
results = run_exhaustive_comparison;
```

该入口保留Branch1--3各一种正式响应方法，并枚举Branch4从9次实测观测中任选3--9次的全部466种子集，总计469种复响应方法。每种方法固定运行6个两站、4个三站和1个四站定位，最终输出5159条全流程；7个名义相位不足、设计矩阵秩为2的三观测组合及其77条定位链保留并显式标记失败。

默认对所有469种方法统一使用4.5--5.5 GHz内均匀抽取的21个频点。可用`run_exhaustive_comparison('FrequencyCount',51)`提高频点数，但运行时间和缓存体积会相应增加。
