# FEKO 多点仿真代码包

本目录由 `FEKO/NewFeko` 中已经完成的仿真流程整理而来。代码包用于生成 100 个发射源位置的 FEKO 输入文件、批量运行 FEKO，并用 MATLAB 完成 REV、MUSIC 和 CBF 后处理。原目录中的文件未被修改。

## 目录结构

```text
Code/
├─ config.bat                 FEKO 可执行文件路径配置
├─ run_all.bat                批量调用 FEKO
├─ run_pipeline.m             FEKO 与 MATLAB 一键流程
├─ gen_multi_pre.m            生成 100 个 .pre 算例
├─ batch_process.m            批量读取 S 参数并定位
├─ main.m                     单个算例的定位检查
├─ REV_calculate.m            REV 相位恢复
├─ read_feko_port_coords.m    从 .out 读取端口坐标
├─ read_inc_coords.m          读取阵列坐标
├─ visualize_results.py       结果图表生成
├─ Model/                     初始模型和公共输入
│  ├─ 8x8x2.cfx              CADFEKO 初始建模工程
│  ├─ 8x8x2.cfm              FEKO 网格模型
│  ├─ 8x8x2.cfs              CADFEKO 会话文件
│  ├─ 8x8x2.pre              已配置的基础 PRE 文件
│  ├─ 8x8x2_orig_1.pre       原始 PRE 备份
│  └─ two_arrays_8x8.inc     两个 8×8 阵列的坐标
├─ Work/                      自动生成的算例和 FEKO 输出
└─ Output/                    MATLAB 汇总与 Python 图表
```

## 软件要求

- Windows 下的 Altair FEKO。批处理需要 FEKO 安装目录中的 `runfeko.exe`。
- MATLAB，且需支持 `sparameters`（RF Toolbox）。
- 可选：Python 3，以及 `numpy`、`scipy`、`matplotlib`，用于生成汇总图。

`feko.exe` 是求解器程序，而本流程输入为 `.pre` 文件，需要通过 `runfeko.exe` 完成 PREFEKO、求解器和后处理链。`runfeko.exe` 通常与 `feko.exe` 位于同一个 FEKO `bin` 目录。

## 首次配置

用文本编辑器打开 `config.bat`，把 `FEKO_RUNNER` 改为本机 `runfeko.exe` 的绝对路径：

```bat
set "FEKO_RUNNER=D:\Software\FEKO2022\feko\bin\runfeko.exe"
```

其他路径均根据 `Code` 文件夹的位置自动计算，无需修改。整个 `Code` 文件夹可以移动到其他位置。

## 完整运行

1. 在 MATLAB 中将当前文件夹切换到本 `Code` 目录，或直接打开 `run_pipeline.m`。
2. 运行：

   ```matlab
   run_pipeline
   ```

脚本按以下顺序执行：

1. `gen_multi_pre.m` 在 `Work` 中生成 `8x8x2_pos1.pre` 至 `8x8x2_pos100.pre`，同时生成 `source_positions.mat`。
2. `run_all.bat` 读取 `config.bat` 中唯一的 FEKO 路径，对 `Work` 中全部 `.pre` 文件逐个调用 FEKO。
3. `batch_process.m` 读取 FEKO 生成的 `*_SParameter1.s129p`，完成 REV、MUSIC 和 CBF 处理。
4. `Output` 中生成 `batch_results.mat` 和 `results_summary.txt`。

100 个 FEKO 算例可能需要较长时间。批处理在某个算例返回非零退出码时会停止，并保留此前已生成的结果。

## 分步运行

需要检查中间文件时，可按以下顺序操作。

### 1. 生成 PRE 算例

在 MATLAB 中运行：

```matlab
gen_multi_pre
```

发射源网格仍采用原项目已经使用的 4×5×5 余弦间距设置，共 100 个位置。需要调整位置时，只修改 `gen_multi_pre.m` 顶部的 `x_list`、`y_list` 和 `z_list`。

### 2. 批量运行 FEKO

双击 `run_all.bat`，或在命令提示符中执行：

```bat
run_all.bat
```

`.pre` 文件中引用模型的路径为相对于 `Work` 的 `..\Model\8x8x2.cfm` 和 `..\Model\two_arrays_8x8.inc`。

### 3. MATLAB 批量后处理

FEKO 全部完成后，在 MATLAB 中运行：

```matlab
batch_process
```

也可以运行 `main.m` 检查单个算例。默认检查第 1 个算例；修改其中的 `case_index` 可选择其他算例。

### 4. 生成 Python 图表

在 `Code` 目录执行：

```bat
python visualize_results.py
```

脚本从 `Output/batch_results.mat` 读取数据，并把 PNG 图表写回 `Output`。

## 运行数据说明

- `Model` 中的文件是运行所需的只读模型输入；`8x8x2.cfx` 可用 CADFEKO 打开查看初始建模。
- `Work` 中的 `.pre`、`.fek`、`.out`、`.str`、`.bof` 和 `.s129p` 均为可重新生成的工作文件。
- `Output` 中保存后处理结果。
- 重新生成算例会覆盖同名 `.pre` 和 `source_positions.mat`，不会删除 FEKO 已有输出。如改变了位置网格，建议先自行清理 `Work` 中旧算例的输出，避免混用。
