# Branch4：Power REV

先形成 `powerData=abs(ZRev).^2`，之后只拟合功率模型并恢复 `H/(B+H)`，不使用 VNA 相位。`compute_branch4.m` 产生 3--9 状态递增响应、有效掩码和拟合诊断。

`run_exhaustive_response_methods.m`会枚举9次实测观测中任选3--9次的全部466种子集。Branch4的`output/`保存466种方法定义、响应汇总和逐位置一致性；7个只含两个唯一名义相位的三观测子集被标记为秩不足、不可恢复。
