# -*- coding: utf-8 -*-
"""
FEKO 多点定位结果可视化
读取 batch_results.mat，生成出版级图表到 output/ 文件夹
"""
import os, sys
import numpy as np
from scipy.io import loadmat
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.ticker import FormatStrFormatter
import matplotlib.gridspec as gridspec

# ========== 配置 ==========
# 中文字体支持
import matplotlib.font_manager as fm
zh_fonts = [f for f in fm.findSystemFonts() if 'msyh' in f.lower() or 'simhei' in f.lower() or 'simsun' in f.lower() or 'microsoft yahei' in f.lower()]
if zh_fonts:
    plt.rcParams['font.sans-serif'] = [fm.FontProperties(fname=zh_fonts[0]).get_name()] + plt.rcParams['font.sans-serif']
    plt.rcParams['font.family'] = 'sans-serif'
else:
    # 兜底: 尝试常见中文字体名
    plt.rcParams['font.sans-serif'] = ['Microsoft YaHei', 'SimHei', 'SimSun', 'DejaVu Sans']
    plt.rcParams['font.family'] = 'sans-serif'
plt.rcParams['axes.unicode_minus'] = False
plt.rcParams.update({
    'font.size': 12,
    'axes.titlesize': 13,
    'axes.labelsize': 12,
    'font.family': 'sans-serif',
    'figure.dpi': 150,
    'savefig.dpi': 300,
    'savefig.bbox': 'tight',
    'savefig.pad_inches': 0.1,
})

OUTDIR = os.path.dirname(os.path.abspath(__file__))

# ========== 读取数据 ==========
data = loadmat(os.path.join(os.path.dirname(OUTDIR), 'batch_results.mat'))
positions = data['positions']           # N×3
err_music = data['err_music_all'].ravel() * 100  # cm
err_cbf   = data['err_cbf_all'].ravel() * 100

N = len(positions)
x, y, z = positions[:, 0], positions[:, 1], positions[:, 2]
err = err_music  # MUSIC & CBF 一致, 任取

# 阵列位置 (天花板)
pa1 = np.array([3.0, 2.0, 3.0])
pa2 = np.array([7.0, 6.0, 3.0])

print(f"加载 {N} 个点, 误差范围: {err.min():.1f} ~ {err.max():.1f} cm")

# ========== Fig 1: 逐z层热力图矩阵 ==========
z_unique = np.sort(np.unique(z))
nz = len(z_unique)
cols = 3
rows = 2

fig, axes = plt.subplots(rows, cols, figsize=(5.5*cols, 5*rows))
axes = axes.reshape(rows, cols)

vmin, vmax = np.percentile(err[err < 400], [2, 98])  # 排除极端值做色标

for idx, zv in enumerate(z_unique):
    ax = axes.flat[idx]
    mask = np.abs(z - zv) < 0.01
    if not mask.any():
        continue
    xi, yi = np.meshgrid(
        np.linspace(x[mask].min()-0.3, x[mask].max()+0.3, 80),
        np.linspace(y[mask].min()-0.3, y[mask].max()+0.3, 80))
    from scipy.interpolate import griddata
    zi = griddata((x[mask], y[mask]), err[mask], (xi, yi), method='cubic')

    im = ax.pcolormesh(xi, yi, zi, cmap='RdYlBu_r', vmin=vmin, vmax=vmax,
                       shading='auto', rasterized=True)
    ax.scatter(x[mask], y[mask], c=err[mask], cmap='RdYlBu_r',
               vmin=vmin, vmax=vmax, edgecolors='k', linewidths=0.3, s=40, zorder=3)
    ax.plot(pa1[0], pa1[1], '^', color='dodgerblue', markersize=10, zorder=4)
    ax.plot(pa2[0], pa2[1], '^', color='dodgerblue', markersize=10, zorder=4)
    ax.set_title(f'z = {zv:.2f} m')
    ax.set_xlabel('X (m)'); ax.set_ylabel('Y (m)')
    ax.set_xlim(0, 10); ax.set_ylim(0, 8)
    ax.set_aspect('equal')

# hide empty subplot (6th slot)
for idx in range(nz, rows*cols):
    axes.flat[idx].set_visible(False)

cbar_ax = fig.add_axes([0.92, 0.12, 0.015, 0.75])
fig.colorbar(im, cax=cbar_ax, label='定位误差 (cm)')
fig.suptitle('FEKO 多点定位误差热力图 (MUSIC, UTD+混凝土墙)', y=1.02, fontsize=14)
plt.subplots_adjust(right=0.90, wspace=0.3, hspace=0.35)
fig.savefig(os.path.join(OUTDIR, 'fig1_heatmap_by_z.png'))
plt.close()
print("fig1 done")

# ========== Fig 2: 3D 散点图 ==========
fig = plt.figure(figsize=(10, 7))
ax = fig.add_subplot(111, projection='3d')

# 裁剪极端值以清晰显示
err_plot = np.clip(err, 0, 400)
sc = ax.scatter(x, y, z, c=err_plot, cmap='RdYlBu_r', s=50,
                edgecolors='k', linewidths=0.3, alpha=0.9)

# 阵列位置
ax.scatter(*pa1, c='lime', marker='^', s=150, edgecolors='k', linewidths=1, label='PA1')
ax.scatter(*pa2, c='lime', marker='^', s=150, edgecolors='k', linewidths=1, label='PA2')

ax.set_xlabel('X (m)'); ax.set_ylabel('Y (m)'); ax.set_zlabel('Z (m)')
ax.set_xlim(0, 10); ax.set_ylim(0, 8); ax.set_zlim(0, 3)
ax.view_init(elev=25, azim=-60)
ax.set_title('3D 空间定位误差分布')
cbar = fig.colorbar(sc, ax=ax, shrink=0.6, pad=0.1)
cbar.set_label('误差 (cm)')
ax.legend(loc='upper left')
plt.tight_layout()
fig.savefig(os.path.join(OUTDIR, 'fig2_3d_scatter.png'))
plt.close()
print("fig2 done")

# ========== Fig 3: 统计面板 (直方图+CDF+箱线) ==========
fig = plt.figure(figsize=(12, 5))
gs = gridspec.GridSpec(1, 2, width_ratios=[1, 1.2])

# 直方图
ax1 = fig.add_subplot(gs[0])
err_clip = err[err < 500]
ax1.hist(err_clip, bins=30, color='steelblue', edgecolor='white', alpha=0.85)
ax1.axvline(np.mean(err_clip), color='red', linestyle='--', linewidth=2,
            label=f'均值={np.mean(err_clip):.0f} cm')
ax1.axvline(np.median(err_clip), color='darkorange', linestyle='-', linewidth=2,
            label=f'中位={np.median(err_clip):.0f} cm')
ax1.set_xlabel('定位误差 (cm)')
ax1.set_ylabel('频次')
ax1.set_title('误差分布直方图 (排除>5m极端值)')
ax1.legend()

# CDF
ax2 = fig.add_subplot(gs[1])
sorted_err = np.sort(err)
cdf = np.arange(1, N+1) / N
ax2.plot(sorted_err, cdf, 'steelblue', linewidth=2)
ax2.axhline(0.5, color='gray', linestyle=':', alpha=0.5)
ax2.axhline(0.9, color='gray', linestyle=':', alpha=0.5)
ax2.axvline(np.percentile(err, 50), color='darkorange', linestyle='--',
            label=f'P50={np.percentile(err, 50):.0f} cm')
ax2.axvline(np.percentile(err, 90), color='red', linestyle='--',
            label=f'P90={np.percentile(err, 90):.0f} cm')
ax2.set_xlabel('定位误差 (cm)')
ax2.set_ylabel('累积概率')
ax2.set_title('误差累积分布函数 (CDF)')
ax2.legend()
ax2.grid(True, alpha=0.3)

fig.suptitle('FEKO 多点定位误差统计', fontsize=14)
plt.tight_layout()
fig.savefig(os.path.join(OUTDIR, 'fig3_statistics.png'))
plt.close()
print("fig3 done")

# ========== Fig 4: 误差 vs 到阵列距离 ==========
fig, axes = plt.subplots(1, 2, figsize=(12, 5))

dist1 = np.sqrt(np.sum((positions - pa1)**2, axis=1))
dist2 = np.sqrt(np.sum((positions - pa2)**2, axis=1))
dist_min = np.minimum(dist1, dist2)

axes[0].scatter(dist1, err, c=z, cmap='viridis', s=25, alpha=0.7, edgecolors='none')
axes[0].set_xlabel('到PA1距离 (m)'); axes[0].set_ylabel('误差 (cm)')
axes[0].set_title('误差 vs PA1距离')
axes[0].grid(True, alpha=0.3)
axes[0].set_ylim(0, 500)
cbar0 = fig.colorbar(axes[0].collections[0], ax=axes[0])
cbar0.set_label('Z (m)')

axes[1].scatter(dist2, err, c=z, cmap='viridis', s=25, alpha=0.7, edgecolors='none')
axes[1].set_xlabel('到PA2距离 (m)'); axes[1].set_ylabel('误差 (cm)')
axes[1].set_title('误差 vs PA2距离')
axes[1].grid(True, alpha=0.3)
axes[1].set_ylim(0, 500)
cbar1 = fig.colorbar(axes[1].collections[0], ax=axes[1])
cbar1.set_label('Z (m)')

fig.suptitle('定位误差与阵列距离关系', fontsize=14)
plt.tight_layout()
fig.savefig(os.path.join(OUTDIR, 'fig4_distance_analysis.png'))
plt.close()
print("fig4 done")

# ========== Fig 5: 综合信息图 (四象限) ==========
fig = plt.figure(figsize=(14, 10))
gs = gridspec.GridSpec(2, 2, height_ratios=[1, 0.9])

# 左上: z=1.5 层热力图 (最有代表性)
ax1 = fig.add_subplot(gs[0, 0])
mask_z15 = np.abs(z - 1.5) < 0.3
xi, yi = np.meshgrid(np.linspace(0, 10, 100), np.linspace(0, 8, 80))
zi = griddata((x[mask_z15], y[mask_z15]), err[mask_z15],
              (xi, yi), method='cubic')
im = ax1.pcolormesh(xi, yi, zi, cmap='RdYlBu_r', vmin=vmin, vmax=vmax,
                    shading='auto', rasterized=True)
ax1.scatter(x[mask_z15], y[mask_z15], c=err[mask_z15], cmap='RdYlBu_r',
            vmin=vmin, vmax=vmax, edgecolors='k', linewidths=0.3, s=35, zorder=3)
ax1.plot(pa1[0], pa1[1], 'D', color='lime', markersize=12, zorder=4, label='PA1')
ax1.plot(pa2[0], pa2[1], 'D', color='lime', markersize=12, zorder=4, label='PA2')
ax1.set_title('z≈1.5m 平面热力图'); ax1.set_xlabel('X (m)'); ax1.set_ylabel('Y (m)')
ax1.set_xlim(0, 10); ax1.set_ylim(0, 8); ax1.set_aspect('equal')
ax1.legend(loc='upper right', fontsize=9)
fig.colorbar(im, ax=ax1, label='误差 (cm)', shrink=0.8)

# 右上: 小提琴图/箱线图 按z分层
ax2 = fig.add_subplot(gs[0, 1])
z_labels = [f'{v:.2f}' for v in z_unique]
box_data = [err[np.abs(z - v) < 0.01] for v in z_unique]
bp = ax2.boxplot(box_data, labels=z_labels, patch_artist=True,
                 showfliers=False, widths=0.5)
for patch in bp['boxes']:
    patch.set_facecolor('steelblue')
    patch.set_alpha(0.7)
ax2.set_xlabel('Z 层 (m)'); ax2.set_ylabel('误差 (cm)')
ax2.set_title('各高度层误差分布')
ax2.grid(True, alpha=0.3, axis='y')
ax2.set_ylim(0, 400)

# 左下: 误差热力图覆盖阵列覆盖范围
ax3 = fig.add_subplot(gs[1, 0])
sorted_by_x = np.argsort(x)
# 按 x 分组的平均误差
x_bins = np.array([0, 2, 4, 6, 8, 10])
x_digit = np.digitize(x, x_bins)
y_bins = np.array([0, 2, 4, 6, 8])
y_digit = np.digitize(y, y_bins)
grid_err = np.full((len(y_bins), len(x_bins)), np.nan)
grid_cnt = np.zeros_like(grid_err)
for i in range(N):
    gy = y_digit[i] - 1
    gx = x_digit[i] - 1
    if 0 <= gy < len(y_bins) and 0 <= gx < len(x_bins):
        if np.isnan(grid_err[gy, gx]):
            grid_err[gy, gx] = err[i]
            grid_cnt[gy, gx] = 1
        else:
            grid_err[gy, gx] += err[i]
            grid_cnt[gy, gx] += 1
grid_err = grid_err / np.maximum(grid_cnt, 1)
im3 = ax3.imshow(grid_err, cmap='RdYlBu_r', aspect='auto', origin='lower',
                 extent=[0, 10, 0, 8], vmin=vmin, vmax=vmax)
ax3.plot(pa1[0], pa1[1], 'D', color='lime', markersize=14, zorder=4)
ax3.plot(pa2[0], pa2[1], 'D', color='lime', markersize=14, zorder=4)
ax3.set_title('粗粒度误差热力图'); ax3.set_xlabel('X (m)'); ax3.set_ylabel('Y (m)')
ax3.set_xlim(0, 10); ax3.set_ylim(0, 8); ax3.set_aspect('equal')
fig.colorbar(im3, ax=ax3, label='误差 (cm)', shrink=0.8)

# 右下: 文本统计摘要
ax4 = fig.add_subplot(gs[1, 1])
ax4.axis('off')
# 分区统计
center_mask = (x > 3) & (x < 7) & (y > 2) & (y < 6)
corner_mask = ((x < 2) | (x > 8)) & ((y < 1.5) | (y > 6.5))
edge_mask = ~center_mask & ~corner_mask

stats_lines = [
    '========== 定位误差统计 ==========',
    f' 总采样点数: {N}',
    f'',
    f' 全局:',
    f'   均值 = {np.mean(err):.1f} cm',
    f'   中位 = {np.median(err):.1f} cm',
    f'   标准差 = {np.std(err):.1f} cm',
    f'   最小 = {err.min():.1f} cm',
    f'   最大 = {err.max():.1f} cm',
    f'',
    f' 房间中央 (n={center_mask.sum()}):',
    f'   均值 = {np.mean(err[center_mask]):.1f} cm',
    f'   中位 = {np.median(err[center_mask]):.1f} cm',
    f'',
    f' 边缘区域 (n={edge_mask.sum()}):',
    f'   均值 = {np.mean(err[edge_mask]):.1f} cm',
    f'   中位 = {np.median(err[edge_mask]):.1f} cm',
    f'',
    f' 角落区域 (n={corner_mask.sum()}):',
    f'   均值 = {np.mean(err[corner_mask]):.1f} cm',
    f'   中位 = {np.median(err[corner_mask]):.1f} cm',
    f'',
    f'================================',
]
for i, line in enumerate(stats_lines):
    ax4.text(0.05, 0.95 - i*0.04, line, transform=ax4.transAxes,
             fontsize=10, verticalalignment='top')

fig.suptitle('FEKO 多点定位仿真 — 综合分析', fontsize=15, y=1.01)
plt.tight_layout()
fig.savefig(os.path.join(OUTDIR, 'fig5_dashboard.png'))
plt.close()
print("fig5 done")

print(f"\n全部 5 张图已保存到 {OUTDIR}")
