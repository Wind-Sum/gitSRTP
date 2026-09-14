# Branch1：Complex DFT

对前8个唯一相位下的完整复数总响应 `ZRev` 提取一阶DFT，得到阵元复响应 `HRevComplex`，作为与Branch4同源的复数参考。3--7状态使用模型 `Z(theta)=B+H exp(j theta)` 的复谐波最小二乘；第9次360°是0°重复观测，不进入正式DFT基准。

正式实现与采集结果中原始`HRevComplex`在四个位置的相对差异均为`10^-15`量级。`output/exhaustive_response_methods.csv`和`output/exhaustive_response_summary.csv`记录本分支唯一正式方法。
