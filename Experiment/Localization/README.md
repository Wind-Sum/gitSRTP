# AOA 定位层

本目录只消费 `../FourBranchRev/output/four_branch_responses.mat` 中的规范复响应，不在定位阶段重新定义 REV。

完整闭环可直接运行 `../run_closed_loop_analysis.m`；以下入口用于只重算本层。

统一运行：

```matlab
cd('Experiment/Localization')
results = run_localization_analysis;
```

每个分支都会输出：

- 4 个单阵位 DOA；
- 6 个两站组合；
- 4 个三站组合；
- 1 个四站组合。

两站结果是两条方向直线最近点的中点；三站和四站结果是到所有方向直线垂距平方和最小的鲁棒解。Branch1会对3--7观测的复谐波LS、8相位DFT和9次含闭合重复的观测进行扫描；Branch4会对对应3--9次功率观测进行扫描。

Branch1的正式定位使用8个唯一相位的复数DFT响应；Branch4的正式定位使用相同8相位的功率REV响应。第9次360°仅在状态递增表中作为0°闭合重复观测。

`run_exhaustive_localization.m`读取穷举响应缓存，对469种响应方法逐一运行6个两阵位、4个三阵位和1个四阵位组合，共5159条定位链，并输出逐链、逐方法和按“每阵位REV相移观测数”汇总的结果。相移观测数与参与定位的阵位数是两个独立维度。

`run_music_bartlett_comparison.m`在同一复响应缓存上补算单快拍形式的MUSIC，并与上述Bartlett结果逐方法、逐阵位组合配对。两者各有1876条单阵位DOA和5159条定位链。统一入口`../run_exhaustive_comparison.m`默认运行两种DOA算法。MUSIC在每个位置、频点只使用一个阵列复响应向量形成秩一协方差；这是一项现有数据上的流程对照，不能解释为独立多快拍条件下的性能评比。

默认穷举缓存在4.5--5.5 GHz内统一使用21个频点。5159条链中5082条得到数值定位；77条来自7个秩不足响应方法。数值结果中有84条两站/三站结果未通过全部射线向前检查，四站结果均通过。

射线RMS只衡量定位点到各AOA方向线的垂距一致性，不是真值误差；多条带有共同偏差的射线可以在错误位置紧密交汇。完整解释和总体结果见`../EXHAUSTIVE_RESULTS_SUMMARY.md`。

主要穷举输出位于`output/`：`exhaustive_doa.csv`、`exhaustive_full_pipeline.csv`、`exhaustive_method_summary.csv`、`exhaustive_group_summary.csv`和`EXHAUSTIVE_COMPARISON_REPORT.md`。

新增对照输出：`music_exhaustive_doa.csv`、`music_exhaustive_localization.csv`、`music_vs_bartlett_doa.csv`、`music_vs_bartlett_pipeline.csv`、`music_vs_bartlett_group_summary.csv`和`MUSIC_BARTLETT_COMPARISON_REPORT.md`。原有文件仍明确表示Bartlett结果。
