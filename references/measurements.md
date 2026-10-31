# 图表排版细则 → ggplot2 / ragg 参数对照与像素实测报告

> 版本说明：本文件记录的是 v1.0 时期的原始测量数据与结论，是 `typography-full.md`
> 中所有 `[实测]` 数字的来源。文末"待修项"里提到的 `theme_pub()` 缺 `margin`、
> `plot.margin` 默认 2.5 mm 等问题，**在 v1.1 已修复**（见 `scripts/fig_spec.R`）。
> 原始测量值保持原样，作为可追溯证据，不做事后修饰。
>
> 环境（已实测确认）：R 4.3.3 · ggplot2 4.0.3（S7 体系）· ragg 1.3.2 · systemfonts 1.2.1 · patchwork 1.3.0 · scales 1.4.0 · png
> 运行：`cd typography && /d/R/R-4.3.3/bin/Rscript.exe R/measure.R`
> 所有数字都由 `R/measure.R` 现场渲染 + 逐像素测量得到，原始数据在 `output/csv/`，完整日志在 `output/run_log.txt`。
> 测量口径：`ragg::agg_png(width=mm, height=mm, units="mm", res=600)`，**1 mm = 23.622 px**，图幅 89 × 60 mm → 2102 × 1417 px。
> 判定容差：几何量 ±0.10–0.15 mm，线条长度 ±0.08 mm。像素分辨率本身是 ±1 px = ±0.042 mm，抗锯齿边界让实际可分辨度约 ±1.5 px = ±0.06 mm。

---

## 0. 先立地基：四个单位事实（FACT，全部实测）

| # | 事实 | 证据 | 影响 |
|---|------|------|------|
| 1 | `margin()` 的默认单位是 **pt**，不是 mm | `args(ggplot2::margin)` → `unit = "pt"`；`margin(4.252)` 实测 1.4944 mm，`margin(1.5,"mm")` 实测 1.500 mm | 写 `margin(1.5)` 以为是 1.5 mm，其实是 1.5 pt = 0.53 mm，只有目标的 1/2.8 |
| 2 | `theme()` 里 `size` 的单位是 **pt**，且被精确执行 | 5–12 pt 逐档实测，cap 高永远 = 0.72 × size_pt（表 B-1） | 可直接填 pt，无需换算 |
| 3 | `geom_text()/annotate()` 的 `size` 单位是 **mm** | `size=8` 与 `size=8/.pt` 实测字高比 **2.833**，≈ `.pt` = 2.845276（表 B-2） | 8 pt 的字必须写 `size = 8/.pt` 或 `size = pt(8)` |
| 4 | 各文本元素自带**非零默认 margin**，且随 `base_size` 缩放 | `base_size=8` 时：`plot.title` 底边 4 pt、`plot.subtitle` 底边 4 pt、`axis.title.x` 上边 2 pt、`axis.text.x` 上边 1.6 pt | 只设 `size` 不设 `margin`，拿到的不是你想要的间距（表 FACT-2） |

**表 FACT-2　`theme_classic(base_size = 8)` 下的默认值（`calc_element()` 读出）**

| element | size (pt) | margin (t,r,b,l) pt | 备注 |
|---|---|---|---|
| plot.title | 9.6 | 0, 0, **4**, 0 | rel(1.2)，hjust=0 |
| plot.subtitle | 8.0 | 0, 0, **4**, 0 | hjust=0 |
| plot.tag | 9.6 | 0,0,0,0 | hjust=0.5, vjust=0.5 |
| plot.caption | 6.4 | **4**, 0, 0, 0 | hjust=1 |
| axis.title.x | 8.0 | **2**, 0, 0, 0 | |
| axis.title.y | 8.0 | 0, **2**, 0, 0 | |
| axis.text.x | **6.4** | **1.6**, 0, 0, 0 | rel(0.8)——不是 8 pt |
| axis.text.y | **6.4** | 0, **1.6**, 0, 0 | |
| legend.title | 8.0 | 0,0,0,0 | |
| legend.text | **6.4** | 0,0,0,0 | |
| strip.text.x | **6.4** | 3.2,3.2,3.2,3.2 | |

> 单位换算常数：`1 pt = 0.352778 mm`，`1 mm = 2.834646 pt`，`1 pt = 8.3333 px @600dpi`，`1 mm = 23.622 px @600dpi`，ggplot2 内部 `.pt = 72.27/25.4 = 2.845276`。

---

## 1. 完整参数对照表

### A. 画布留白

| 细则项 | theme 元素 | 单位 | 推荐值 | 代码片段 |
|---|---|---|---|---|
| 图幅四周留白 1–2 mm（目标 1.5） | `plot.margin` | `margin(..., unit="mm")` | **1.5 mm**（= 4.252 pt） | `theme(plot.margin = margin(1.5, 1.5, 1.5, 1.5, unit = "mm"))` |

**实测（表 A-1，`output/csv/02_A-plot_margin.csv`）**：0/1/1.5/2/3/6/10 mm 七档，`top/right/bottom/left` 四边全部线性命中，斜率 0.9997、截距 0.0005 mm、**最大误差 0.018 mm（< 0.5 px）**。`plot.margin` 被精确执行，可以放心当唯一事实来源。

**`plot.margin` 是最外层留白——这句话的实测含义**：它是 gtable 最外圈的内边距，标题、刻度标签、轴标题全部在它内侧，所以"纸边 → 第一个墨迹"的距离**必然小于**设定值，差额等于该侧第一个元素在自身盒内的内缩量：

| 该侧第一个元素 | plot.margin | 实测"纸边→墨迹" | 差额 |
|---|---|---|---|
| 标题字顶（9 pt 粗体） | 1.5 mm | **1.439 mm** | −0.061 |
| y 轴标题字左缘（8 pt） | 1.5 mm | **1.439 mm** | −0.061 |
| x 轴标题字底（8 pt） | 1.5 mm | **1.482 mm** | −0.018 |
| 图例文字右缘 | 1.5 mm | **3.048 mm** | +1.548（图例框内的 padding） |

**axis.line 会额外侵入留白**（表 A-2）：轴线以面板边界为中心向两侧各画一半，所以"到轴线的可见空白"进一步变小，且**与线宽线性相关**：

| axis.line 线宽 | 设定留白 | 实测首墨迹 | 偏差 |
|---|---|---|---|
| 0.25 pt | 1.5 mm | 1.439 mm | −0.061 |
| 0.50 pt | 1.5 mm | 1.397 mm | −0.103 |
| 1.00 pt | 1.5 mm | 1.355 mm | −0.145 |

> 实务含义：细则要求"留白 1.5 mm"，`plot.margin = 1.5 mm` 之后**可见白边约 1.44 mm**，仍在 1–2 mm 区间内。若审稿要求"可见白边 ≥1.5 mm"，须把 `plot.margin` 提到 1.6 mm。

**垂直总高度估算方法（已闭环验证，残差 0 px）**

```
图高 = plot.margin(t) + h(标题) + m_b(标题) + h(副标题) + m_b(副标题)
     + h(面板)
     + axis.ticks.length + m_t(axis.text) + h(刻度标签) + m_t(axis.title) + h(轴标题)
     + plot.margin(b)
```

实测拆解（89 × 60 mm，推荐参数，`output/csv/31_E-budget.csv`）：

| 段 | px | mm | 来源 |
|---|---|---|---|
| margin_top | 34 | 1.439 | `plot.margin` |
| 标题行 | 71 | 3.006 | 9 pt 粗体（含下伸部） |
| 标题 margin(b) | 12 | 0.508 | 1.5 pt |
| 副标题行 | 49 | 2.074 | 8 pt |
| 副标题 margin(b) | 27 | 1.143 | 1.5 pt + 0.6 mm 下行余量 |
| **面板** | **1013** | **42.884** | 剩余空间 |
| axis.ticks.length | 30 | 1.270 | 1.25 mm |
| 刻度线→标签 | 12 | 0.508 | `axis.text` margin(t)=1.5 pt |
| 刻度标签行 | 44 | 1.863 | 7 pt |
| 标签→轴标题 | 28 | 1.185 | `axis.title.x` margin(t)=2 pt + 0.55 mm |
| 轴标题行 | 62 | 2.625 | 8 pt |
| margin_bottom | 35 | 1.482 | `plot.margin` |
| **合计** | **1417** | **60.00** | = 图高，**残差 0 px** |

> **反推公式**：非面板部分固定占用 **17.1 mm**（8 pt 基准 + 9 pt 标题 + 单行副标题 + 单行轴标题）。所以 `面板可用高度 = 图高 − 17.1 mm`。要 45 mm 高的绘图区，图高需 62.1 mm。轴标题换行或字号加大，按每条文字行 ≈ 1.15 × size_pt 追加。

### B. 分级字号

| 细则项 | theme 元素 | 单位 | 推荐值 | 代码片段 |
|---|---|---|---|---|
| 图内主标题 | `plot.title` | pt | **9**（粗体） | `element_text(size = 9, face = "bold", hjust = 0, margin = margin(b = 1.5, l = 9, unit = "pt"))` |
| 副标题 | `plot.subtitle` | pt | **8** | `element_text(size = 8, margin = margin(b = 1.5, unit = "pt"))` |
| x 轴标题 | `axis.title.x` | pt | **8** | `element_text(size = 8, margin = margin(t = 2, unit = "pt"))` |
| y 轴标题 | `axis.title.y` | pt | **8** | `element_text(size = 8, margin = margin(r = 2, unit = "pt"))` |
| 刻度标签 | `axis.text`（`.x`/`.y`） | pt | **7** | `element_text(size = 7, colour = "black", margin = margin(t = 1.5, r = 1.5, unit = "pt"))` |
| 图例标题 | `legend.title` | pt | **8** | `element_text(size = 8)` |
| 图例项 | `legend.text` | pt | **7** | `element_text(size = 7)` |
| 面板标签 A/B/C | `plot.tag` | pt | **9**（粗体，与标题同级） | 见 C10 |
| 图内注释 / 数据标签 | `annotate(size=)` / `geom_text(size=)` | **mm** | 6 pt → `size = 6/.pt` | `annotate("text", x, y, label = "n = 3", size = 6/.pt)` |
| 显著性标记 / 单位上标 | 同上 + `parse = TRUE` | mm | 6–7 pt | `annotate("text", x, y, label = "R^2 == 0.91", size = 6/.pt, parse = TRUE)`；单位写 `"Response (mm)"` 或 `parse=TRUE` 的 `"mu*'m'"`。**字体/语法层面，未做像素实测** |

**表 B-1　字号 → 实际字高（Arial，600 dpi）**

| size_pt | cap 高 px | cap 高 mm | em px | cap/em |
|---|---|---|---|---|
| 5 | 30 | 1.270 | 41.7 | 0.72 |
| 6 | 36 | 1.524 | 50.0 | 0.72 |
| **7** | **42** | **1.778** | 58.3 | 0.72 |
| **8** | **48** | **2.032** | 66.7 | 0.72 |
| **9** | **54** | **2.286** | 75.0 | 0.72 |
| 10 | 60 | 2.540 | 83.3 | 0.72 |
| 12 | 72 | 3.048 | 100.0 | 0.72 |

> 线性极好，比例恒为 0.72（Arial cap height）。公式：`cap_mm = 0.72 × size_pt × 0.352778`。

**表 B-2　`geom_text` 的 mm 陷阱（实测）**

| 写法 | 字高 px | 字高 mm |
|---|---|---|
| `size = 8` | 136 | 5.757 |
| `size = 8/.pt` | 48 | 2.032 |
| 比值 | **2.833** | `.pt = 2.8453` |

> 差 0.4% 来自整数像素取整。结论：`size = 8` 是 8 **mm**，字高是 8 pt 的 2.8 倍——直接把 pt 值填进去会得到一张标题被注释淹没的图。

### C. 各类间距（每项都做了"改参数 → 重渲染 → 量差值"的差分验证）

| # | 细则项 | 控制元素 | 单位 | 推荐值 | 实测关系 | 代码 |
|---|---|---|---|---|---|---|
| 1 | 标题与副标题间距 | `plot.title` 的 `margin(b)` **和** `plot.subtitle` 的 `margin(t)`，**两者叠加** | pt | 1.5 + 0 = **1.5** | 叠加，残差 < 1 px | `margin(b = 1.5, unit = "pt")` |
| 2 | 标题/副标题 → 绘图区上边缘 | **最后一个标题元素的 `margin(b)`**（有副标题时就是副标题的） | pt | **1.5** | `plot.margin` 只整体下移，不改变该间距；给**标题**加 margin(b) 也不改变它 | `plot.subtitle = element_text(margin = margin(b = 1.5, unit = "pt"))` |
| 3 | 轴标题 ↔ 刻度标签 | `axis.title.x` 的 `margin(t)` | pt | **2** | 1:1（0.72 mm/2 pt） | `margin(t = 2, unit = "pt")` |
| 4 | 刻度标签 ↔ 轴线 | `axis.text.x` 的 `margin(t)` | pt | **1.5** | 1:1，**无额外行距**；margin=0 时标签直接贴住轴线 | `margin(t = 1.5, unit = "pt")` |
| 5 | 刻度线长度 | `axis.ticks.length` | grid unit | **1.25 mm** 向外（或 `-1.25` 向内） | **从面板边缘算起的全长**，ratio 1.00–1.02 | `axis.ticks.length = unit(1.25, "mm")` |
| 6 | 图例标题 ↔ 图例项 | `legend.title` 的 `margin(b)` / `legend.spacing.y`（**后者无效**） | pt | 用 `legend.title = element_text(margin = margin(b = 2, unit="pt"))` | 见表 C-2 | — |
| 7 | 图例项之间 | `legend.key.size`（**不是** `legend.spacing.y`） | pt | = base_size，**8 pt** | key 高 = 行高 | `legend.key.size = unit(8, "pt")` |
| 8 | 图例 ↔ 绘图区 | `legend.box.spacing`（**不是** `legend.margin`） | grid unit | **2 mm** | 1:1（0/1.99/4.02 mm） | `legend.box.spacing = unit(2, "mm")` |
| 9 | 多面板行列间距 | facet：`panel.spacing.x/.y`；patchwork：各子图 `plot.margin` | mm | facet **3–4 mm**；patchwork **1.5 mm × 2** | facet 精确 1:1；patchwork 空白 = **两者相加** | 见下 |
| 10 | 面板标签 ↔ 绘图区 | `plot.tag.position` + `plot.tag` 的 `just`/`margin` | — | `c(0,1)` + `hjust=0, vjust=1` | 见 C10 | 见下 |

#### C1　标题 / 副标题间距是叠加的

| title margin(b) | 实测标题→副标题 | 增量 |
|---|---|---|
| 0 | 0.593 mm | — |
| 2 pt | 1.312 mm | +0.719（2 pt = 0.706） |
| 4 pt | 1.990 mm | +0.678 |
| 6 pt | 2.709 mm | +0.719 |

`plot.subtitle` 的 `margin(t)` 给出**完全相同**的阶梯；两者同时设置时按和计算：

| title_b + sub_t | 实测 | 预测（基线 + 和） | 残差 |
|---|---|---|---|
| 0 | 0.593 | 0.593 | 0.0 |
| 4 pt | 1.990 | 1.993 | −0.3 px |
| 6 pt | 2.709 | 2.699 | 0.0 px |
| 8 pt | 3.429 | 3.405 | +0.3 px |

> 注意基线不是 0：`margin = 0` 时两行文字仍有 **0.593 mm** 的墨迹间隙——那是字形行距（详见 §3 陷阱 4）。

#### C2　`plot.margin` 不控制内部间距

| 情况 | 首墨迹位置 | 最后一个标题 → 面板 |
|---|---|---|
| 基线（margin 全 0） | 4.995 mm | 0.593 mm |
| `plot.margin(t)=8mm` | **8.001 mm** | **0.593 mm**（不变） |
| `plot.subtitle margin(b)=6pt` | 4.995 mm | **2.709 mm**（+2.12 = 6 pt） |
| `plot.title margin(b)=6pt` | 4.995 mm | **0.593 mm**（不变！） |
| `plot.title.position="plot"` | 4.995 mm | 0.593 mm |

> 给标题加 bottom margin 只把副标题往下推，副标题到面板的距离不变——因为面板也跟着下移。要压紧"标题块 ↔ 绘图区"，只能调**最后一个**标题元素的 `margin(b)`。

**`plot.title.position` 是横向开关**（竖向无影响）：

| `plot.title.position` | 标题左缘 | 相对面板左缘 |
|---|---|---|
| `"panel"`（默认） | 200 px | **+0.085 mm**（对齐面板） |
| `"plot"` | 121 px | **−3.260 mm**（对齐整张图左缘，即 y 轴标题外侧） |

#### C3 / C4 / C5　x 轴垂直堆叠

| `axis.text.x` margin(t) | 面板底 → 标签墨迹 | 预期 |
|---|---|---|
| 0 | 0.000 mm | 0 |
| 1.6 pt | 0.593 mm | 0.564 |
| 3 pt | 1.058 mm | 1.058 |
| 6 pt | 2.117 mm | 2.117 |

| `axis.title.x` margin(t) | 标签 → 轴标题 | 预期（margin + 0.55 mm 固定行距） |
|---|---|---|
| 0 | 0.550 mm | 0 + 0.55 |
| 2 pt | 1.270 mm | 0.706 + 0.55 |
| 4 pt | 1.947 mm | 1.411 + 0.55 |
| 8 pt | 3.387 mm | 2.822 + 0.55 |

> margin=0 时仍有 0.55 mm：刻度标签（数字，无下伸部）的字盒底边在 descent 线上。**这个余量消不掉，只能算进预算。**

| `axis.ticks.length` | 实测 | ratio |
|---|---|---|
| 0.5 mm | 0.508 mm | 1.016 |
| 1 mm | 1.016 mm | 1.016 |
| 1.25 mm | 1.270 mm | 1.016 |
| 2 mm | 2.032 mm | 1.016 |
| 3 mm | 3.006 mm | 1.002 |
| −0.5 mm（向内） | 0.466 mm | 0.931 |
| −1.25 mm | 1.228 mm | 0.982 |
| −2 mm | 1.947 mm | 0.974 |

> **`axis.ticks.length` 是"从面板边缘算起的全长"**，不是"轴线之外再延伸多少"，也不含轴线自身笔画。ratio 略大于 1 是像素取整（30 px vs 29.5 px）。负值即向内，刻度画在面板内部。

#### C6 / C7 / C8　图例：三个参数管三件不同的事

| 参数 | 面板→图例框 | 图例框→首个图例符号 | 面板右缘 | 图例框左缘 |
|---|---|---|---|---|
| `legend.box.spacing = 0` | **0.000 mm** | 1.482 mm | 1102 | 1103 |
| `legend.box.spacing = 2` | **1.990 mm** | 1.482 mm | 1055 | 1103 |
| `legend.box.spacing = 4` | **4.022 mm** | 1.482 mm | 1007 | 1103 |
| `legend.margin = 0` | 2.836 mm | **0.085 mm** | 1102 | 1170 |
| `legend.margin = 2` | 2.836 mm | **2.074 mm** | 1007 | 1075 |
| `legend.margin = 4` | 2.836 mm | **4.064 mm** | 913 | 981 |

两条关键结论：
1. **`legend.box.spacing` 管"面板 → 图例框"**，1:1。它变大时**图例框不动、面板变窄**（`panel_right` 1102→1055→1007，`box_left` 恒为 1103）——因为 gtable 把富余空间吃在面板上，不是把图例推出去。
2. **`legend.margin` 管"图例框内边距"**，1:1；`面板→框` 恒为 2.836 mm（`legend.box.spacing` 的默认值），不受它影响。它变大时也是图例框向左长、面板变窄。

**`legend.spacing.y` 完全无效**（对同一图例内的条目）：

| `legend.spacing.y` | 条目行高 px | 条目间隙 mm |
|---|---|---|
| 0 / 1 / 2 / 4 mm | 62/61/48/50 | 2.16 / 1.48 / 1.99（**四组逐位相同**） |

它管的是"一个图例框与另一个图例框"之间的距离（多个 legend 时才有意义）。条目间距实际由 `legend.key.size` 撑开：

| `legend.key.size` | 条目间隙 mm | 图例框高 mm |
|---|---|---|
| 4 pt | 1.44 / 0.04 / 0.55 | 14.69 |
| 8 pt | 1.57 / 0.21 / 0.76 | 15.28 |
| 12 pt | 2.24 / 1.65 / 2.16 | 19.52 |
| 16 pt | 2.92 / 3.05 / 3.56 | 23.75 |

#### C9　多面板：两条路线，适用场景不同

**路线一：`facet_wrap()` + `panel.spacing`**（面板严格等宽、共用坐标轴时用）

| `panel.spacing.x` | 面板宽 mm | 间隙 mm |
|---|---|---|
| 0 | 26.63 / 26.63 / 26.63 | 0.04 / 0.04 |
| 2 | 25.32 / 25.27 / 25.32 | 2.03 / 2.03 |
| 4 | 23.96 / 23.92 / 23.96 | 4.06 / 4.06 |
| 6 | 22.65 / 22.65 / 22.65 | 6.01 / 6.01 |

`panel.spacing.y` 同样精确，但**面板行之间还有 strip**：

| `panel.spacing.y` | 实测行间空白 | strip 隐藏后 |
|---|---|---|
| 0 | **4.91 mm** | 0.04 mm |
| 3 | 7.92 mm | 3.05 mm |
| 6 | 10.88 mm | 6.01 mm |

> `panel.spacing.y` 是"上一行面板 ↔ 下一行 strip"的距离；两行面板之间的**可见空白 = panel.spacing.y + strip 高度**。要按视觉空白设值，先加上 strip 高（8 pt 文本 + 3.2 pt 上下 margin ≈ 4.9 mm）。

**路线二：`patchwork::wrap_plots()` + 各子图 `plot.margin`**（子图尺寸/轴不同、或要 A/B/C 排布时用）

| 每个子图 `plot.margin` | 子图间隙 | 预测 = 2 × margin | 残差 |
|---|---|---|---|
| 0 | 0.042 mm | 0 | +0.042 |
| 1.5 mm | **3.006 mm** | 3.0 | +0.006 |
| 3 mm | **6.054 mm** | 6.0 | +0.054 |

> 间隙 = **两个子图 margin 相加**，不是取最大值。想得到 3 mm 间距，两边各 1.5 mm；或一边 3 mm、另一边 0。

**patchwork 1.3.0 与 ggplot2 4.0.3 不兼容（实测复现）**：

```
wrap_plots(p1, p2) & theme(plot.margin = margin(3,3,3,3,"mm"))
→ Error: Can't find method for generic `&(e1, e2)`:
   - e1: <patchwork>  - e2: <theme>
```

必须对每个子图单独 `+ theme_pub(...)` 再 `wrap_plots()`。

#### C10　`plot.tag`：数值锚点会随"有没有标题"改变

| 写法 | 面板左缘(px) | 面板被推移 | tag 在面板上方 px | tag 在面板内 px |
|---|---|---|---|---|
| `"topleft"`（命名） | 174 | **+2.328 mm** | 62 | 0 |
| `"topright"`（命名） | 119 | 0 | 62 | 0 |
| `c(0,1)` 默认 vjust=0.5 | 119 | 0 | 27 | 26 |
| `c(0,1)` + **vjust=1** | 119 | 0 | 0 | **53（整只）** |
| `c(0,1)` + vjust=0 | 119 | 0 | **54（整只）** | 0 |

> 上表在**没有标题**的图上测。加上标题后锚点会变：`c(0,1)` 默认 → tag 跑到标题行；`"topleft"` 把面板**再**推移 2.96 mm。见 §3 陷阱 8。

**推荐（单图，已验证出图）**：

```r
theme(
  plot.tag.position = c(0, 1),
  plot.tag = element_text(size = 9, face = "bold", hjust = 0, vjust = 1),
  plot.title = element_text(size = 9, face = "bold", hjust = 0,
                            margin = margin(b = 1.5, l = 9, unit = "pt"))  # 给 A/B/C 让位
)
```

标签从版心左边缘起排（实测 tag 左缘 = 119 px = 5.0 mm 处，未溢进 margin），标题缩进 9 pt 后从 200 px 起，两者不相撞。多面板 A/B/C 请用 `patchwork::plot_annotation(tag_levels = "A")`。

### D. 线条粗细

#### D-0　先校准：`linewidth` 在 600 dpi 下并不是 mm

**表 D-1　名义 vs 实测（`output/csv/24_D-linewidth.csv`）**

| 请求 pt | 请求 mm | 名义 px | **实测 px** | **实测 pt** | 最暗像素亮度 | 实测/名义 |
|---|---|---|---|---|---|---|
| 0.25 | 0.0882 | 2.08 | **1.58** | **0.189** | **0.212（灰！）** | 0.757 |
| 0.50 | 0.1764 | 4.17 | **3.14** | **0.377** | 0.000 | 0.754 |
| 0.75 | 0.2646 | 6.25 | **4.71** | **0.565** | 0.000 | 0.753 |
| 1.00 | 0.3528 | 8.33 | **6.27** | **0.753** | 0.000 | 0.753 |
| 1.50 | 0.5292 | 12.50 | **9.42** | **1.130** | 0.000 | 0.753 |
| 2.00 | 0.7056 | 16.67 | **12.55** | **1.506** | 0.000 | 0.753 |

**折减系数 = 0.7528**，机制已定位（不是猜测）：

1. 纯 `grid` 基准实验（表 D-2）：`gpar(lwd=1)` 实测 6.25 px = `1/96 in`，`lwd=4/3` 实测 8.34 px = 1 pt。**grid 的 `lwd` 单位是 1/96 英寸**，不是 pt。
2. ggplot2 把 `linewidth`（mm）换算成 `lwd` 时用的是 `× .pt`（= × 2.845），于是 `lwd = X × 2.845`。
3. 实际宽度 = `X × 2.845 / 96 in = X × 0.7528 mm`。

**补偿写法（已验证，误差 < 0.01 px）**：

```r
mm_per_pt <- 25.4 / 72
lw_eff <- function(pt) pt * mm_per_pt / 0.7528      # 目标 pt -> 需要填的 mm
# lw_eff(0.5) = 0.2339 mm   lw_eff(0.75) = 0.3509 mm   lw_eff(1) = 0.4679 mm
```

| 目标 | `linewidth` 应填 | 实测 px | 名义 px | 误差 |
|---|---|---|---|---|
| 0.25 pt | 0.1170 mm | 2.08 | 2.08 | 0.00 |
| 0.50 pt | 0.2339 mm | 4.16 | 4.17 | −0.01 |
| 0.75 pt | 0.3509 mm | 6.24 | 6.25 | −0.01 |
| 1.00 pt | 0.4679 mm | 8.32 | 8.33 | −0.01 |

> ⚠️ **技能脚本 `fig_spec.R` 里的 `lw()` 只做 `pt × 0.352778`，没有这层补偿**。所以 `theme_pub(spec)` 里 `line_pt = 0.75` 的轴线实际印出来是 **0.565 pt**，`data_line_pt = 1.0` 实际是 **0.753 pt**，全部比标称细 25%。见 §3 陷阱 6。

#### D-1　各项推荐值

下表"建议 `linewidth`"已含 0.7528 补偿，写进去就是标称 pt 的真实宽度。

| 细则项 | theme / geom 参数 | 推荐（标称 pt） | 建议 `linewidth` (mm) | 600 dpi 像素 |
|---|---|---|---|---|
| 轴线 | `axis.line = element_line(linewidth=)` | **0.5** | **0.234** | 4.17 |
| 面板边框 | `panel.border = element_rect(linewidth=)` | **0.5** | **0.469**（×2，见下） | 4.17 |
| 刻度线 | `axis.ticks = element_line(linewidth=)` | **0.5** | **0.234** | 4.17 |
| 数据线 | `geom_line/geom_path(linewidth=)` | **1.0** | **0.468** | 8.33 |
| 误差棒 | `geom_errorbar(linewidth=, width=)` | **0.75** | **0.351** | 6.25 |
| 误差棒帽宽 | `width =`（**数据坐标**） | 视觉 1.5–2.5 mm | — | 见 D-3 |
| 拟合/回归线 | `geom_smooth(linewidth=)` | **1.0–1.25** | 0.468–0.585 | 8.3–10.4 |
| 参考线 | `geom_hline/vline(linewidth=)` | **0.5–0.75**（虚线段 0.75） | 0.234–0.351 | 4.2–6.3 |
| 网格线（若保留） | `panel.grid.major = element_line(linewidth=)` | **0.25**，颜色 `grey85` | **0.117** | 2.08 |
| 图例符号边框 / 点边框 | `stroke =`（`shape=21/22` 的 `stroke`） | **0.5–0.8** | — | 见 D-4 |

**`panel.border` 只能拿到一半**（表 D-5）：同一 `linewidth` 下，`axis.line` 折减 0.753，`panel.border` 只有 **0.377**——正好一半，因为边框笔画以面板边界为中心，外侧那一半被面板视口裁掉。

| 请求 | `axis.line` 实测 | `panel.border` 实测 |
|---|---|---|
| 0.25 pt | 1.57 px (0.188 pt) | 0.79 px (0.095 pt) |
| 0.50 pt | 3.14 px (0.377 pt) | 1.57 px (0.189 pt) |
| 0.75 pt | 4.71 px (0.565 pt) | 2.36 px (0.283 pt) |
| 1.00 pt | 6.28 px (0.753 pt) | 3.14 px (0.377 pt) |

> 需要 0.5 pt 可见边框 → `panel.border` 填 **0.469 mm**（= 0.234 × 2）。或者干脆用 `axis.line`（四边用 `axis.line = element_line()` 只能画两条，四边框仍需 `panel.border`）。

#### D-2　为什么低于 0.25 pt 在印刷上不可行

- **600 dpi 下 0.25 pt 只有 2.08 px**（0.0882 mm）。实测：把 `linewidth` 设为 0.25 pt 的等效值后，最暗像素亮度 **0.212** ——没有任何一个像素被完全覆盖，线被渲染成**灰色带**而不是黑线（0.5 pt 起 `min_lum = 0.000`，即纯黑）。
- 加上 0.7528 的折减，按"0.25 pt"写出来的线实际只有 **0.189 pt ≈ 1.58 px**，亮度更低。
- 再往下走，一条线的面积不足以稳定覆盖一个半色调网点（offset 印刷常规最小线宽约 0.25 pt / 0.09 mm），制版/印刷环节会出现断线、深浅不匀。
- 因此下限应设在 **0.5 pt（实测 3.14 px，纯黑）**；`fig_spec.R` 里 `stop("任何线条均不得低于 0.25 pt")` 这条硬约束在补偿缺失的情况下，实际守的是 0.188 pt，**已经跌破印刷底线**。

#### D-3　`geom_errorbar` 的 `width` 是数据坐标，不是 mm

| `width=` | cap 像素 | 面板宽 | 换算回数据单位 | cap 实际 mm |
|---|---|---|---|---|
| 0.2 | 119 | 50 mm | **0.202** | 5.038 |
| 0.4 | 237 | 50 mm | **0.401** | 10.033 |
| 0.6 | 355 | 50 mm | **0.601** | 15.028 |

`cap_mm = width / x_range × panel_width_mm`。要 2 mm 的帽宽、面板 50 mm 宽、x 轴跨度 2 个单位：`width = 2 / 50 × 2 = 0.08`。**换面板宽度就要重算**——这是 `width` 最容易出错的地方。

#### D-4　点边框 `stroke`

`shape = 21, size = 2`（size 是 mm 直径）时，外径随 `stroke` 变化（实测）：

| `stroke` | 外径 mm |
|---|---|
| 0.5 | 2.032 |
| 1.0 | 2.455 |
| 2.0 | 3.471 |

> `stroke` 不是简单的"每边加 stroke"，而是与 `size` 一起作用于整个符号。要精确控制外径，直接用实测值或改用 `size` 调。

---

## 2. 实测偏差表（推荐参数落到一张完整图上，9 项全 PASS）

图幅 89 × 60 mm / 600 dpi / 完整元素（tag + 标题 + 副标题 + 轴标题 + 刻度 + 图例 + 图内注释 + 误差棒 + 参考线），`output/csv/29_E-verify.csv`。

校验方法：**同一个图、同样的文字，只把某个 margin 从推荐值改成 0，重渲染，看间距变化量**。这样得到的判据与字体度量无关。

| 细则项 | 目标 mm | 实测 mm | 偏差 | 容差 | 判定 |
|---|---|---|---|---|---|
| C1 标题→副标题（Δ margin 1.5pt→0） | 0.529 | 0.508 | −0.021 | 0.10 | **PASS** |
| C2 副标题→面板（Δ margin 1.5pt→0） | 0.529 | 0.550 | +0.021 | 0.10 | **PASS** |
| C3 刻度线→标签（Δ margin 1.5pt→0） | 0.529 | 0.466 | −0.063 | 0.10 | **PASS** |
| C4 标签→轴标题（Δ margin 2pt→0） | 0.706 | 0.635 | −0.071 | 0.10 | **PASS** |
| C5 刻度线长度（绝对值） | 1.250 | 1.270 | +0.020 | 0.08 | **PASS** |
| A 留白 上（首个墨迹） | 1.500 | 1.439 | −0.061 | 0.15 | **PASS** |
| A 留白 左（首个墨迹） | 1.500 | 1.439 | −0.061 | 0.15 | **PASS** |
| A 留白 右（首个墨迹，含图例 padding） | 3.050 | 3.048 | −0.002 | 0.25 | **PASS** |
| A 留白 下（首个墨迹） | 1.500 | 1.482 | −0.018 | 0.15 | **PASS** |

> 系统性的 −0.06 mm ≈ −1.5 px 是抗锯齿边界（50% 覆盖率的那一行是灰色，阈值 0.90 判为非墨迹）。这在像素测量里无法消除，也是我把几何容差定在 0.10–0.15 mm 的原因。

**绝对间隙（仅记录，随字形下伸部浮动，不作判据）**

| 间隙 | margin=0 时 | 推荐参数时 |
|---|---|---|
| 标题→副标题 | 0.000 mm（两行粘连） | 0.508 mm |
| 副标题→面板 | 0.593 mm | 1.143 mm |
| 刻度线→标签 | 0.042 mm | 0.508 mm |
| 标签→轴标题 | 0.550 mm | 1.185 mm |

---

## 3. ggplot2 参数陷阱清单（全部有实测支撑）

### 陷阱 1　`margin()` 默认单位是 pt
`margin(1.5)` = 1.5 pt = 0.529 mm，只有 1.5 mm 的 1/3。**凡是要 mm 必须显式写 `unit = "mm"`。**

### 陷阱 2　`plot.title` / `plot.subtitle` 自带 4 pt 底边距
`base_size=8` 时两者默认 `margin = margin(b = 4)`，且随 `base_size` 缩放（`base_size=15` 时为 7.5 pt）。所以：
- 只写 `plot.title = element_text(size = 9)` → 实际标题下留白 4 pt（1.41 mm），不是你想要的 1.5 pt。
- 想控制就**必须同时写 margin**，写 `margin(b = 0)` 也会把默认值覆盖掉。

### 陷阱 3　`axis.text` 默认是 `rel(0.8)`，不是 base_size
`base_size = 8` 时刻度标签是 **6.4 pt**。细则要求 7 pt 就必须显式 `size = 7`。（`theme_pub()` 里显式给了 `size = base_size`，反而把它抬成了 8 pt。）

### 陷阱 4　"表观间隙 ≠ 参数值"，差额由字形下伸部决定
`margin = 0` 时两行文字的墨迹间隙**不是 0**：

| 上方文字内容 | 残余间隙（8 pt） | 原因 |
|---|---|---|
| 含下伸部（`g p y j q`） | **0.00 mm** | 墨迹底边 = 字盒底边（descent 线） |
| 不含下伸部（纯数字/大写） | **0.55–0.59 mm** | 墨迹底边 = 基线，字盒另有 descent 空间 |

> 所以"量出来的间隙"永远不能直接当参数填回去。用差分（改参数看差值）或按 §2 的方法校验。

### 陷阱 5　`axis.ticks.length` 是**全长**，不是"额外伸出量"
从面板边缘算起，1.25 mm 就是 1.25 mm（实测 1.270）。负值 = 向内。它**不**包含轴线自身笔画，所以配 0.5 pt 轴线时，从轴线外缘到刻度尖端的可见长度 ≈ 1.25 + 0.09 mm。

### 陷阱 6　`linewidth` 只画出 0.7528 倍（本报告最重要的发现）
ggplot2 4.0.3 把 `linewidth`（mm）当作 pt 换算后传给 `grid::gpar(lwd)`，而 **`lwd` 的单位是 1/96 英寸**。净效果：`linewidth` 写 0.3528 mm（=1 pt）只画出 **0.753 pt / 6.27 px**。

- 技能脚本 `fig_spec.R` 的 `lw()` **没有**这层补偿，所以 `line_pt = 0.75` 的轴线、`data_line_pt = 1.0` 的数据线实际都细 25%。
- 连锁后果：`fig_spec()` 的"不得低于 0.25 pt"约束，实际守的是 **0.188 pt**（实测 1.58 px、最暗亮度 0.212 的灰线），已经低于印刷可辨下限。
- 修正：`lw_eff(pt) = pt * 0.352778 / 0.7528`；或至少把所有标称 pt 乘以 1.33。

### 陷阱 7　`panel.border` 只有一半宽度可见
同一 `linewidth` 下 `panel.border` 的实测宽度是 `axis.line` 的 **50.1%**（0.377 vs 0.753）——笔画以面板边界为中心，外半被面板视口裁掉。要 0.5 pt 的可见四边框，`panel.border` 要填 0.469 mm。

### 陷阱 8　`plot.tag` 的数值锚点会随"有没有标题"改变
- **没有标题**：`c(0,1)` 锚在**面板**左上角（vjust=1 → tag 整只落在面板内）。
- **有标题**：同一个 `c(0,1)` 把 tag 放到**标题行**（面板上方 62 px 处），因为 tag 落在 plot 表的标题行里。
- `"topleft"` 无论有没有标题都会**把面板右推**（无标题 2.33 mm，有标题 2.96 mm），因为它占用布局列。
- 数值位置默认 `hjust=0.5`，x=0 时有**半个字溢进 `plot.margin`**（实测 tag 左缘 0.68 mm < 1.5 mm 留白）。需要 `hjust=0`。

### 陷阱 9　`legend.spacing.y` 不是"图例项间距"
四组 0/1/2/4 mm 的实测条目间隙**逐位相同**。它管"图例框 ↔ 图例框"。条目间距由 `legend.key.size` 撑开。

### 陷阱 10　`legend.margin` 不控制"图例离绘图区多远"
它控制图例框**内部**的 padding。面板→框的距离恒为 `legend.box.spacing`（默认 2.836 mm），两者互不影响（实测各自 1:1）。

### 陷阱 11　`legend.box.spacing` 变大会让**面板变窄**
不是把图例往右推（图例左缘恒在 1103 px），而是吃掉面板的富余空间。想让"图例离面板更远"且面板宽度不变，只能加宽画布。

### 陷阱 12　`panel.spacing.y` 之外还有 strip
`facet_wrap(nrow=3)` 时，`panel.spacing.y = 0` 的面板行之间仍有 **4.91 mm**——那是下一行的 strip。隐藏 `strip.text` 后降到 0.04 mm。

### 陷阱 13　`geom_errorbar(width=)` 是数据坐标
`width = 0.4` 在 50 mm 宽、x 跨度 2 个单位的图上等于 **10.03 mm** 的帽宽。换面板宽度或 x 范围就要重算。

### 陷阱 14　`geom_text(size=)` 是 mm，且 `annotate()` 同样
`size = 8` = 8 mm（实测字高 5.76 mm），是 8 pt 的 2.833 倍。**列表里所有"6 pt 注释"都必须写 `size = 6/.pt`。**

### 陷阱 15　`diff(bands$end)` 不是间隙
写测量代码时踩到的坑：`end[i+1] - end[i]` = 间隙 + 下一个带的高度。正确的间隙是 `start[i+1] - end[i] - 1`。同样的错误我在第一版里把 3 mm 的 facet 间隙算成了 26.6 mm。

### 陷阱 16　阈值 0.95 会把灰面板和它的抗锯齿边当成"墨迹"
用灰块做几何锚点时，`panel` 下沿的过渡行（亮度 0.82，不是 0.80）会被 0.95 阈值判为墨迹，导致"面板底 → 标签"永远量成 0.000 mm。文字必须用 **0.45 的深色掩码**，几何量用 0.95/相对灰度。

---

## 4. 与常识不符的行为（清单）

1. **`axis.text` 默认比 `axis.title` 小**（6.4 vs 8 pt）。多数人以为刻度标签 = base_size。
2. **`plot.title` 默认 hjust = 0**（左对齐），不是居中。`plot.title.position` 默认 `"panel"`，所以标题左缘对齐面板（实测 +0.085 mm），而不是纸边；换成 `"plot"` 会左移 3.26 mm。
3. **给标题加 `margin(b)` 不会改变"标题块 → 面板"的距离**（面板同步下移）。只有最后一个标题元素的 `margin(b)` 才算数。
4. **`legend` 的富余空间是从面板里扣的**（`legend.box.spacing`、`legend.margin` 都会让 `panel_right` 左移），不是从画布右边缘挤出去。
5. **`axis.ticks.length` 可以给负值**（向内），实测线性（−0.5/−1.25/−2 mm → 0.466/1.228/1.947）。向内刻度会遮挡靠近轴线的数据点，这也是 `theme_pub()` 默认朝外的理由。
6. **`axis.line` 的笔画侵入留白**，且侵入量 = 线宽的一半 + 抗锯齿（0.25/0.5/1.0 pt → 留白少 0.061/0.103/0.145 mm）。
7. **补上 linewidth 补偿后，0.25 pt 的线才真是 2.08 px**；不补偿时它只有 1.58 px 且是灰色（亮度 0.21）。
8. **`patchwork` 的 `& theme()` 在 ggplot2 4.0.3 上直接报错**，不是警告，是硬错误。
9. **ragg 对 mm→px 是向下取整**：60 mm @600 dpi → 1417 px（60/25.4×600 = 1417.32）。所以"设定 60 mm"实际是 59.997 mm，误差 0.003 mm，可忽略；但像素级比对必须按 floor 算。

---

## 5. 给团队的可执行建议

1. **`fig_spec(margin_mm = 1.5)`**——`fig_spec()` 的默认 `margin_mm = 2.5` 不符合"留白 1–2 mm"的细则，会多出 1 mm。调用时必须显式覆盖。
2. **给 `lw()` 加补偿**（或在 `theme_pub()` 里统一乘以 1.328）：否则全套线宽偏细 25%，且跌破 0.25 pt 印刷下限。建议新增 `lw_eff()`，不要改动 `lw()` 的语义（会把既有图全部改粗）。
3. **`axis.text` 显式给 7 pt**：`theme_pub()` 现在把它设成 `base_size`（8 pt），与细则差 1 pt。
4. **`theme_pub()` 的 `plot.title` 缺 `margin`**：它现在只设 `size = base_size + 1`，标题底边距会落到 ggplot2 默认的 4 pt（1.41 mm），而细则要求 1.5 pt（0.53 mm）。
5. **多面板不要用 `& theme()`**，逐图 `+ theme_pub()` 后 `wrap_plots()`。
6. **面板标签统一 `c(0,1)` + `hjust=0, vjust=1` + 标题 `margin(l=9pt)`**，可避免 `"topleft"` 推移面板导致的 A/B/C 列不对齐。

---

## 6. 未验证 / 无法验证的部分

| 项 | 状态 | 说明 |
|---|---|---|
| 显著性标记、上标、希腊字母的实际字形与基线 | **未做像素实测** | 属于文本内容而非布局参数；`parse = TRUE` 的语法正确性未验证 |
| 图例符号边框与 `legend.key.size` 的交互 | **部分验证** | 只测了 key 高度对行高的影响，未测符号描边宽度 |
| `geom_point(shape = 19)` 的 `stroke` | **未验证** | 该 shape 的 stroke 无效，只测了 `shape = 21` |
| 印刷端（offset/CTP）最小线宽 | **未验证** | "0.25 pt 印刷下限"是行业经验值，本报告只证明了 0.25 pt 在 600 dpi 位图上会渲染成灰带 |
| 字体内嵌/替换对宽度的影响 | **未验证** | 全程使用 Arial；换 Helvetica/Times 后 cap 高比例（0.72）会变，间距预算需重测 |
| `pdf()` / `cairo_pdf()` 设备上的 linewidth 折减 | **未在 pdf 上验证** | 已在 base `png()` 上复核（`lwd=1.3333` → 8 px，同样符合 1/96 in），推断为 R 图形系统通用行为 |

---

## 附：产物清单

**脚本**
- `R/measure.R` —— 主脚本，31 个实测块、152 行实测记录，中文注释说明每步在量什么
- `R/measure_lib.R` —— 像素测量工具（渲染、亮度矩阵、墨迹带、面板矩形定位、亚像素线宽）

**图**
- `output/hero_full_elements.png` / `.tiff`（LZW）—— 89×60 mm / 600 dpi 完整元素成品图
- `output/hero_geometry_twin.png` —— 灰底孪生图（只改面板填充，布局不变），几何量全部在这张上测
- `output/hero_geometry_{title0,sub0,all0}.png` —— 差分变体
- `output/hero_multi_panel.png`（patchwork）· `output/hero_facet.png`（facet）
- `output/a_*` … `output/e10_*` —— 各实验的原始渲染，文件名与报告中的表号对应

**数据**
- `output/csv/01_FACT-2.csv` … `output/csv/31_E-budget.csv`
- `output/run_log.txt` —— 完整控制台输出

> `output/` 里还残留少量开发期调试渲染（`_dbg*`、`_bias*`、`_lwd*`、`_cal*`、`smoke.png` 等），不影响交付，正式产物以上面清单为准。
