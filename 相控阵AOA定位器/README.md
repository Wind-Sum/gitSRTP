# 相控阵 AOA 定位器（REV + MUSIC + AOA，单频 / 宽带双模式）

Windows 桌面软件：输入若干阵位的**阵元坐标 + 各相移下的相控阵合成功率**表格，
输出**预测坐标**。内部完整实现 **逐频点 REV → 逐频点 MUSIC → 频点间非相干平均 →
多阵位 AOA 稳健交汇**，运行时不调用 MATLAB、不依赖 MATLAB Runtime 或 Python
（MATLAB 只在开发期用于交叉验证，见 §5.1）。

---

## 1. 运行方式（便携文件夹，不是单文件 EXE）

解压 `发布\相控阵AOA定位器.zip`，双击其中的：

```
相控阵AOA定位器.exe
```

**必须保留同目录的 `data\`、`flutter_windows.dll`、`icudtl.dat`** ——
这是 Flutter Windows 的标准发布结构（约 27 MB），
**不能只复制一个 EXE**。也可以把 CSV 拖到 exe 图标或程序窗口上打开。

---

## 2. 输入格式（长表，推荐）

一行 = 一个阵元在一个频点下的各相移合成功率；支持任意阵位数与任意频点数。

```csv
StationID,ElementID,X_m,Y_m,Z_m,Frequency_Hz,P_deg_0,P_deg_45,P_deg_90,P_deg_135,P_deg_180,P_deg_225,P_deg_270,P_deg_315,P_deg_360
Location1,1,1.197500,-0.110000,1.742500,4500000000.000000,1.358e-07,6.740e-08,1.669e-07,...
```

| 列 | 说明 |
|---|---|
| StationID | 阵位标识；多文件时可用文件名区分 |
| ElementID | 阵元编号 |
| X_m / Y_m / Z_m | 阵元坐标（米） |
| Frequency_Hz | 该行频点（Hz） |
| P_deg_* | 该相移下的合成功率（**线性功率**） |

- **单频模式**：输入只有一个唯一 `Frequency_Hz`，每阵位 32 行。
- **宽带模式**：输入有两个或更多唯一 `Frequency_Hz`，每阵位 32 × F 行。
  21 频点、32 阵元、9 个采集状态时每阵位 32×21×9 = 6048 个功率值。
- 相移角度写在列名里（`P_deg_90`；旧写法 `P90`、`相移90`、`90°` 也可）。
- **0° 与 360° 等价**：0°–315° 共 8 个唯一状态用于 REV 拟合；
  `P_deg_360` 是与 `P_deg_0` 同一物理状态的重复采集，**不参与 REV**，
  只用于 0°/360° **功率闭合检查**（见 §3.2）。
- 功率单位必须显式指定（线性 / dB / dBm），软件**不会根据正负号猜测**。

模板与示例见 `发布\相控阵AOA定位器\示例\`，也可在软件“表格格式要求”页另存模板。

### 2.1 随包示例（全部是真实实测数据）

软件**不再内置一键载入的示例**：在“选择数据文件”页直接选中下面的 CSV 即可
（可多选、可拖放、也可把路径粘贴进去）。

| 文件（`示例\` 目录） | 内容 | 各阵位方位角 | 预测坐标 (X, Y, Z) m |
|---|---|---|---|
| `示例_四阵位_单频5.0GHz.csv` | 4 阵位 × 32 阵元 × 1 频点（每阵位 32 行） | 124.620760 / 66.138674 / 95.318727 / 115.199226 | (0.616026, −0.756689, 1.544125) |
| `示例_四阵位_宽带21频点.csv` | 4 阵位 × 32 阵元 × 21 频点（每阵位 672 行） | 122.826728 / 142.188517 / 95.166781 / 69.956037 | (−0.256677, 2.062304, 1.557939) |
| `示例_四阵位_宽带21频点_两阵位版.csv` | 同上去掉后两个阵位，体积小、跑得快 | 122.826728 / 142.188517 | (0.229459, 1.585472, 1.446798) |
| `单频输入模板.csv` / `宽带输入模板.csv` | 空表头 + 少量示例行，自己填（**含 `P_deg_360` 列**，可选，仅用于闭合检查） | — | — |

三个示例的每一行列结构为
`StationID,ElementID,X_m,Y_m,Z_m,Frequency_Hz,P_deg_0,P_deg_45,P_deg_90,P_deg_135,P_deg_180,P_deg_225,P_deg_270,P_deg_315,P_deg_360`
（共 9 个相移列，15 列）。它们都取自
`Experiment\Real_test\results\Location{1,2,3,4}\REV_Localization_*\REV_Localization_Result.mat`：
`powerData = abs(ZRev).^2` → 8 个唯一相移（0°–315°）逐频点 REV → 逐频点 MUSIC →
频点间非相干平均 → AOA → 四阵位多射线稳健定位；
阵元坐标 = 实测阵列中心 + MATLAB `cfg.localElementPositionsM`（32 端口顺序）。

> ⚠️ **阵位数量会显著改变预测坐标**：同一批实测数据，2 个阵位与 4 个阵位的结果相差约 0.66 m。
> 原因有两个：
> 1. 阵位越少，方向射线交汇的几何约束越弱（条件数变差），坐标不确定度越大；
> 2. 实测 AOA 本身带有系统偏差（该批数据相对真值 (0, 3.09, 1.50) m 偏差约 1.1 m，
>    属仪器、位置记录、阵列姿态与多径共同形成的系统误差），
>    阵位少时这种偏差更难被平均掉，甚至会出现射线不完全向前的情况。
>
> 所以**要与实验报告对照，请用四阵位的两个示例**；两阵位版只用于快速试跑。
> 三个示例的正确性由 `dart run tool/test_docs.dart` 核对
> （因 CSV 只保留 10 位有效数字，与参考值的差约 4e-7°，远优于 0.05° 的判据），
> 并与 MATLAB R2024b 实机结果交叉验证（见 §5）。

支持一次多选多个文件（每个文件一个阵位），或一个含 StationID 的合并表格。
兼容旧格式：单文件前后两段阵列的宽表、以及 `P90@4500` 形式的列名。

---

## 3. 界面能看到的诊断信息

单频/宽带模式、阵位数量、每阵位阵元数、输入频点数与实际使用频点列表、
检测到的相移、REV 实际使用的唯一相移、**0°/360° 功率闭合检查**（见 §3.2）、
逐频点 REV 有效率、每阵位 AOA（方位/俯仰/方向余弦）、
多阵位预测坐标与射线 RMS 垂距、三维场景（阵位 / 射线 / 预测点）、
以及“项目实测兼容 / 通用阵列”模式选择。
数据来源（文件名）与阵位组合会一并显示，并写入导出报告。

### 3.1 逐频点 REV 有效率

每个频点单独做 REV，有效阵元比例即该频点的有效率；
界面上以柱状图逐频点显示，并给出平均有效率。宽带模式下若某些频点有效率明显偏低，
说明该频点测量质量差，其 MUSIC 谱被自动跳过（有效阵元 < 12 时不参与平均）。

### 3.2 0°/360° 功率闭合检查（纯功率域）

**软件输入只有线性功率**：

```
P(0°)   = |Z(0°)|²
P(360°) = |Z(360°)|²
```

仅凭两个实数功率**无法**得到 VNA 的复数相位，因此本软件只给出纯功率域统计量，
界面、导出报告与本文档统一称为“**0°/360° 功率闭合检查**”，
并**不输出**任何“相位差”“相对复误差”之类的量（早期版本有过这类显示，已删除）。

统计范围是**该阵位的全部阵元 × 全部实际载入频点**（宽带模式不是只看第一个频点）：

| 指标 | 定义 |
|---|---|
| 总体功率比 | `mean(P360)/mean(P0)` |
| 归一化 RMS 功率差 | `norm(P360−P0)/max(norm(P0),realmin)` |
| 中位逐点相对功率差 | `median(abs(P360−P0)./max(abs(P0),realmin))` |
| 最大逐点相对功率差 | `max(abs(P360−P0)./max(abs(P0),realmin))` |

界面除全阵位汇总外，还逐频点列出这四个指标；
若归一化 RMS 功率差 > 5%，会给出“该状态采集重复性不佳”的警告。

> 360° **始终不参与 REV 拟合**：REV 只用 0°–315° 这 8 个唯一相移
> （与 `Experiment/FourBranchRev/Branch4/compute_branch4.m` 的 canonical 槽一致）。

---

## 4. 两种运行模式

| 模式 | 说明 |
|---|---|
| **项目实测兼容（默认）** | 严格复刻 MATLAB：固定 32 阵元端口顺序与本地坐标定义、相同阵列中心、相同正半空间约束、相同幅度指数与有效阵元门限、**粗搜索 0.025 / 精搜索 0.0025**、相同方向谱归一化与多射线稳健定位 |
| 通用阵列 | 由表格坐标自动拟合阵面与法向，适合任意阵位几何；搜索网格与有效阵元门限仍与项目一致 |

> 项目兼容模式**不做 PCA 坐标轴重排**，直接使用 MATLAB 定义的阵元坐标与方向坐标轴，
> 因此结果与 MATLAB 同口径。

---

## 5. 与 MATLAB 的一致性验证

验证分两层，**MATLAB 实机交叉验证是唯一可作为“与 MATLAB 一致”依据的结论**；
Python 复刻程序只作为开发期的辅助回归手段。

### 5.1 MATLAB R2024b 实机交叉验证（权威）

MATLAB 侧脚本：`tool/validate_with_matlab.m`。它**只读取** `Experiment/` 中的原始实现，
不修改任何实验文件，并且读取的是与 Flutter **完全相同**的 CSV 输入：

| 项 | 值 |
|---|---|
| MATLAB 版本 | `24.2.0.2740171 (R2024b) Update 1` |
| 实际命令 | `matlab -batch "addpath('tool'); validate_with_matlab('single', fullfile('示例','示例_四阵位_单频5.0GHz.csv'), 'validation')"`（宽带同理，第一个参数改为 `'broadband'`） |
| 调用的原始函数 | `Experiment/FourBranchRev/common/four_branch_config.m`、`recover_power_rev_ls.m`；`Experiment/Localization/common/estimate_broadband_doa.m`（`'Music'`）、`localize_multiray_robust.m` |
| 输入文件 | `示例/示例_四阵位_单频5.0GHz.csv`、`示例/示例_四阵位_宽带21频点.csv` |
| 阵位数 | 4（Location1–Location4） |
| 频点数 | 单频 1 个（5.0 GHz）；宽带 21 个（4.5–5.5 GHz，步进 0.05 GHz） |
| REV 相移集合 | `0,90,180,270,45,135,225,315`（8 个唯一相移；`P_deg_360` 仅用于功率闭合） |
| 搜索参数 | 粗 0.025、精 0.0025、最小有效阵元 12、幅度指数 1 |
| MATLAB 结果文件 | `validation/matlab_single_reference.{txt,doa.csv,rev.csv,position.csv}`、`validation/matlab_broadband_reference.*` |
| 对照报告 | `validation/flutter_matlab_comparison.md`（由 `dart run tool/compare_with_matlab.dart` 生成） |

实测结果（Flutter 对比 MATLAB 实机输出）：

| 比较层级 | 单频 5.0 GHz | 宽带 21 频点 | 判据 |
|---|---|---|---|
| REV 复响应（有效阵元）最大相对差 | 2.2e-15（绝对） | 1.7e-14（绝对）/ 6.9e-12（相对） | 双精度一致 |
| REV 有效掩码不一致个数 | 0 / 128 | 0 / 2688 | 0 |
| 每站方位角最大差异 | 4.715e-11° | 4.641e-11° | < 0.05° ✔ |
| 每站俯仰角最大差异 | 4.956e-11° | 3.595e-11° | < 0.05° ✔ |
| 方向余弦最大差异 | 3.4e-11 | 5.0e-11 | — |
| 最终 X/Y/Z 每维最大差异 | 4.290e-11 m | 4.641e-11 m | < 1 mm ✔ |
| 射线 RMS 垂距差 | 4.1e-12 m | 2.4e-11 m | — |
| 几何条件数差 | 1.4e-11 | 2.5e-11 | — |

MATLAB 实机得到的四阵位坐标：

- 单频 5.0 GHz：`(0.6160259558, −0.7566892362, 1.5441247328) m`，射线 RMS 1.1681608630 m，
  射线非全部向前（与软件一致）。
- 宽带 21 频点：`(−0.2566772853, 2.0623036395, 1.5579389643) m`，射线 RMS 0.2370896296 m，
  射线全部向前。

即 Flutter 与 MATLAB R2024b 读取同一份 CSV 后**逐级达到双精度一致**，
远优于 0.05° / 1 mm 的目标。

### 5.2 与旧实验输出的差异（已查清）

旧实验输出 `Experiment/Localization/output/music_exhaustive_localization.csv`
方法 460 给出的坐标是 `(−0.277830, 2.014043, 1.602432) m`（射线 RMS 0.253155），
与本软件相差约 7 cm。用 MATLAB 实机逐级排查后的确切结论：

1. 用 `Experiment/FourBranchRev/output/exhaustive_response_cache.mat` 中方法 460 的
   REV 复响应复算，四个阵位方位角得到 **122.508162615007 / 143.618019979014 /
   96.033301028903 / 69.4976160620549**，坐标得到 **(−0.277830, 2.014043, 1.602432)** ——
   与旧输出**逐位一致**；而直接从原始 `.mat` 的 `abs(ZRev).^2` 复算是
   122.826728 / 142.188517 / 95.166781 / 69.956037 与 (−0.256677, 2.062304, 1.557939)。
2. 因此差异**不是**算法、相移集合或坐标参考点造成的：
   穷举全部 9 种“8 相移组合”，没有一种能给出 122.5082°（最接近者仍差 0.197°）；
   把参考点从 `cfg.localElementPositionsM` 换成“CSV 坐标减均值”，
   MUSIC 谱完全相同（该变换只平移参考点）。
3. 真正原因是：旧结果是 2026-09-10 生成的**缓存响应**
   （`run_exhaustive_response_methods.m` 的产物）驱动的，
   缓存里的 REV 复响应与从当前原始 `.mat` 重新计算的响应**并非同源**
   （逐阵元最大相对差达 1.6e+01，有效掩码在 Location1/2/4 分别相差 42/26/17 个点）。

证据链保存在 `validation/old_result_vs_raw.md`、`validation/old_result_from_cache.txt`、
`validation/rev_state_convention.txt`（后者证明正式 REV 用 8 个唯一相移：
MATLAB 8 状态结果 `0.211409291339+0.034790509726i` 与 Flutter 一致，
9 状态含 360° 的结果则不同）。

> 结论：本软件以“原始实测 `abs(ZRev).^2` + 8 个唯一相移 + 当前 21 频点选择”为准，
> 该口径已由 MATLAB R2024b 实机确认。

### 5.3 Python 复刻程序（辅助，不作为 MATLAB 一致性依据）

`..\工具\oracle_reference.py` 是独立的公式复刻程序，用于开发期快速回归：

```powershell
# 在软件源码目录
dart run tool/compare_with_oracle.dart single      # 单频 5.0 GHz
dart run tool/compare_with_oracle.dart broadband   # 21 频点宽带
dart run tool/test_docs.dart                       # 校验 示例\示例_四阵位_*.csv
dart run tool/compare_with_matlab.dart             # 与 MATLAB 实机结果逐级对照
```

与 Python 复刻程序的一致度同样在 1e-11 量级，但**只有 §5.1 的 MATLAB 实机结果**
才能作为“与 MATLAB 一致”的证据；在完成 MATLAB 实机验证之前，
本文件曾写作“与独立公式复刻程序一致，MATLAB 实机交叉验证待完成”，
现已按实际验证结果更新。

---

## 6. 从源码构建

```powershell
powershell -ExecutionPolicy Bypass -File .\软件\构建.ps1
```

脚本会：同步源码到 ASCII 构建目录 → `flutter pub get` / `analyze` / `build` →
复制产物到 `发布\相控阵AOA定位器\` → 生成模板与说明 → 生成 ZIP 便携包。

> Flutter 在中文路径下构建会因 MSVC/CMake 代码页问题失败，
> 因此构建在 `srtp_aoa_locator`（纯 ASCII 路径，仅编译镜像，可删除重建）中进行，
> 权威源码始终是本目录。

### 目录结构

```
软件\相控阵AOA定位器\
├── lib\
│   ├── core\
│   │   ├── complex_math.dart     复数、Jacobi 特征分解、最小二乘
│   │   ├── strict_matlab.dart    ★ 严格复刻 MATLAB：REV / MUSIC / 多射线定位 / 频点与相移选择
│   │   ├── strict_pipeline.dart  ★ 正式流程：逐频点 REV → 逐频点 MUSIC → 平均 → AOA → 交汇
│   │   ├── power_closure.dart    ★ 0°/360° 功率闭合检查（纯功率域四项指标）
│   │   ├── survey_models.dart    ★ 长表数据模型（多阵位、多频点、功率单位）
│   │   ├── survey_parser.dart    ★ 长表解析（含旧格式兼容）
│   │   ├── parser.dart           旧格式解析与其公共工具函数
│   │   ├── models.dart / music.dart / rev.dart / aoa.dart / pipeline.dart
│   │   └── （通用模式与旧模型，保留供高级用法）
│   ├── app\app_state.dart        应用状态与流程调用
│   ├── ui\                       界面（自绘图表，无第三方依赖）
│   ├── samples\sample_data.dart  输入模板生成（空模板 + 示例行，含 P_deg_360）
│   └── main.dart
├── windows\                      Windows 外壳（系统文件对话框、多选、拖放）
├── tool\                         命令行校验工具 + MATLAB 验证脚本
├── testdata\                     与 Python 复刻程序对照用的四阵位输入表格
├── 示例\                         单频/宽带模板 + 四阵位实测示例 CSV（随包发布）
├── validation\                   MATLAB 实机参考结果与对照报告
└── 发布\相控阵AOA定位器\          可运行目录 + ZIP 便携包
```

> `示例\示例_四阵位_*.csv` 由 `软件\工具\make_measured_examples.py` 从原始 `.mat`
> 自动生成；更新实测数据后重新运行该脚本即可同步（构建脚本会自动把它们复制进发布包）。

### 命令行工具

```powershell
dart run tool/run_project_case.dart single       # 用四阵位实测输入跑单频全流程
dart run tool/run_project_case.dart broadband    # 用四阵位实测输入跑 21 频点宽带
dart run tool/test_docs.dart                     # 校验 示例\示例_四阵位_*.csv 的结果
dart run tool/compare_with_matlab.dart           # 与 MATLAB R2024b 实机结果逐级对照
dart run tool/compare_with_oracle.dart broadband # 与 Python 复刻程序逐级对比
dart run tool/dump_rev.dart <csv> <loc> <freqIdx> <out.csv>  # 导出 REV 复响应
```

MATLAB 侧与生成脚本：

```powershell
matlab -batch "addpath('tool'); validate_with_matlab('single',    fullfile('示例','示例_四阵位_单频5.0GHz.csv'), 'validation')"
matlab -batch "addpath('tool'); validate_with_matlab('broadband', fullfile('示例','示例_四阵位_宽带21频点.csv'), 'validation')"
matlab -batch "addpath('tool'); debug_cache_vs_raw('validation\old_result_vs_raw.md')"   # 旧结果溯源证据
python 软件\工具\oracle_reference.py            # 逐阵位测试表格 + oracle_reference.txt
python 软件\工具\make_measured_examples.py      # 示例\示例_四阵位_*.csv
```

---

## 7. 仍存在的限制

1. **单文件输入只承载一个阵位**时必须用多文件方式提供多个阵位；
   单个文件含多阵位时必须有 StationID 列。
2. 项目兼容模式的“阵列中心”按阵位顺序套用实测 Location1–4 的中心，
   仅当恰好 4 个阵位且每阵位 32 阵元时启用；其它情况自动改用表格坐标均值中心。
3. 本机 `Experiment` 缓存只保存了 21 个频点，若需要 51 频点口径，
   必须从原始 2001 点 `frequencyHz` 重新抽取并单独运行验证脚本。
4. 本文的“一致性”结论仅指软件与 MATLAB 在**同一输入**上的数值一致性；
   它与“相对信源真值的定位精度”是两件事（实测真值误差约 1.1 m，
   属于仪器、位置记录、阵列姿态与多径共同形成的系统不确定性）。
5. 相位恢复的半球（方向余弦法向分量符号）由正半空间约束确定，
   若实测阵列的实际朝向与约定相反，需要在通用模式下核对坐标轴约定。
6. **软件不内置示例数据**，示例以 CSV 形式放在 `示例\` 目录，由使用者自行选择载入：
   这样“跑的是哪个文件”一目了然，也便于替换成自己的实测数据。
   四阵位宽带示例约 556 KB（解压后发布包约 28 MB）。
7. 单频模式的预测坐标发散度明显大于宽带：该批实测数据在 5.0 GHz 时
   四阵位射线 RMS 达 1.17 m 且射线并非全部向前，
   而 21 频点宽带下 RMS 仅 0.24 m —— 这是实测数据本身的性质，不是软件缺陷。
8. 本机 `Experiment` 缓存（`exhaustive_response_cache.mat`，2026-09-10 生成）中的
   响应与原始 `.mat` 复算结果不同源，二者相差最多 1.6（相对），
   因此**不要**再用该缓存作为验证基准；本软件一律以原始 `abs(ZRev).^2` 为准。
