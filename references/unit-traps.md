# 单位陷阱与"预览≠保存"的六个根因

## 一、换算基准

```
1 inch = 25.4 mm = 72.27 TeX pt ≈ 72 PostScript pt
1 PostScript pt = 0.352778 mm
1 mm = 2.834646 pt
```

R 生态里同时存在两种 pt：ggplot2 内部对字号用 TeX pt（`.pt = 72.27/25.4 ≈ 2.845276`），PostScript/设备用 72 pt/in。差 0.4%，小字号下可忽略，但换算函数必须统一，否则 8 pt 会算出 8.03 pt 或 7.97 pt，在多处叠加后出现对不齐。

## 二、三类单位，三个不同答案

| 出现在哪里 | 单位 | 想写 8 pt 应写 |
|---|---|---|
| `theme(element_text(size = ))` | **pt** | `size = 8` |
| `geom_text()` / `annotate("text")` 的 `size` 美学 | **mm** | `size = 8 / 2.845276` → 用 `pt(8)` |
| `linewidth`（ggplot2 ≥ 3.4） | **mm**，且只画出 0.7528 倍 | `0.75 pt` → `linewidth = 0.75 * 0.4679` → 用 `lw(0.75)` |
| `geom_point(size = )` | **mm**（直径） | 点大小按视觉定，不用 pt 换算 |
| `ggsave(width =, height =)` | **inch**（默认） | 显式写 `units = "mm"` |
| `ragg::agg_tiff(width =, height =)` | **inch**（默认） | 显式写 `units = "mm"` |
| `grid::unit()` | 任意 | — |

**最高频错误**：`geom_text(size = 8)` 以为写 8 pt，实际是 8 mm ≈ 22.7 pt，字号涨 2.84 倍。这个错误在预览里也照样错，所以不会被发现，直到期刊退回。

`fig_spec.R` 提供 `pt()` 与 `lw()` 就是为了消除这类手算。任何示例用 `size = 8` 都是错的，应用 `size = pt(8)`。

## 三、预览与保存不一致的六个根因

### 根因 1：设备不同，像素到物理尺寸的映射不同

RStudio Plots 面板是屏幕设备，逻辑 96 dpi，且宽度由窗口决定。`ggsave()` 是文件设备，有自己的 width/height/dpi。二者没有任何共享参数——面板里看到的"字号看起来正好"完全不能推出文件里也正好。

现象：面板里图例不挤，保存后图例压住数据。
机制：面板宽 800 px，文件宽 2102 px，同一 pt 字号占的像素比不同，文本相对图幅的比例就变了。
做法：预览必须用**与保存完全相同的 width/height/dpi** 渲染成位图再显示，而不是看 Plots 面板。见 `preview_pub()`。

### 根因 2：物理尺寸与像素尺寸混淆

`ggsave("fig.tif", width = 7, height = 5)` 的 7 是**英寸**，等于 177.8 mm。作者以为画了"差不多一栏"，实际是双栏宽度。

现象：单栏投稿被判"图过宽"，或排版后字号异常小。
机制：190 mm 的图印到 90 mm 栏宽，缩放 47%，8 pt 变成 3.8 pt。
做法：一律 `units = "mm"`，宽度直接填期刊栏宽。

### 根因 3：字号单位错用（见上表）

### 根因 4：linewidth 单位是 mm

ggplot2 3.4 起 `size` 在 geom 中拆分为 `linewidth`（线）与 `size`（点/字）。沿用旧代码 `size = 1` 画线，在 3.4+ 会被解释为 mm 而非 pt，线粗 2.83 倍；混用 `size` 与 `linewidth` 还会触发 deprecation warning 并在未来版本失效。

### 根因 5：字体未显式绑定

默认族 `sans` 在不同设备解析到不同实体字体。字宽差异会让自动换行位置、图例宽度、轴标签旋转全部改变。

现象：预览两行图例，保存后变三行并溢出。
做法：`base_family` / `theme(text = element_text(family = ))` 显式指定；中文字体用 `systemfonts::register_font()` 注册后再引用注册名。**不要启用 showtext**：它接管文本栅格化，与 ragg 经 systemfonts/textshaping 的解析路径不同，是预览与输出字形不一致的隐形元凶。

### 根因 6：随机抖动在每次绘制时重新抽样

`geom_jitter()` 每次绘制都重新抽随机偏移。预览抽一次、保存再抽一次，散点落位天然不同。实测：未固定种子时柱状图有 9000 px（0.30%）对不上，看起来像"渲染不一致"，其实是数据位置变了。

`geom_jitter()` **不认 `seed` 参数**（写了会被静默忽略），必须：

```r
geom_point(position = position_jitter(width = 0.08, height = 0, seed = 42))
```

同类问题：`position_dodge()` 无随机性，安全；`geom_sina`/`ggbeeswarm` 默认有随机性，需固定种子。

## 四、dpi 的真相

dpi 只写元数据，**不会增加像素**。

- 一张 900 × 600 px 的图，无论标 300 dpi 还是 600 dpi，像素都是 900 × 600，印在 90 mm 宽时有效分辨率都是 254 dpi。
- 期刊审读的是"最终印刷尺寸下的有效像素数"，即 `像素宽 ÷ (印刷宽/25.4)`。
- 因此正确做法是**先定 mm 与 dpi，让设备算出像素**，而不是先出图再改元数据。

`check_tiff()` 反算的 `physical size` 就是这套关系的验证：`mm = px / dpi * 25.4`。

另一个坑：TIFF 的 `ResolutionUnit`（tag 296）可能为 3（per centimeter）。此时 `dpi = 原始值 × 2.54`，物理尺寸也要用 `px / raw * 10` 算。ragg 实测写的是 2（inch），但其他工具（部分 ImageMagick 配置、扫描仪输出）会写 3，解析时必须分支处理。

## 五、自检代码

```r
source("scripts/fig_spec.R")
check_units()          # 打印换算表
pt(8)                  # 2.8122  —— 传给 geom_text 的 size
lw(0.75)               # 0.3509  —— 传给 linewidth（= 0.75*0.4679，已补偿）
lwb(0.75)              # 0.7019  —— 传给 panel.border（外侧一半被裁，需乘 2）
```
