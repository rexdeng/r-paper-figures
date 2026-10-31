# r-paper-figures

**用 R 出期刊图，让屏幕预览和最终交付的文件长得一模一样。**

`v1.1` · 预览/导出一致 · 五级字号 · 12 项间距 · 线宽补偿 · 可见白边验收

一个 AI Agent 技能（Skill）：把"论文配图必须满足的硬规格"和"预览为什么骗你"这两件事固化成可执行的工作流，而不是每次让模型凭记忆推断。

![line ribbon](docs/figures/line-ribbon.png)

---

## 它解决什么问题

在 RStudio 里看着正常的图，`ggsave()` 之后尺寸、字号、字体、线宽全变了，投稿被退。根因几乎从不是 R 的 bug，而是**同一张图被两套参数渲染了两次**——屏幕设备一套，文件设备一套。

这个技能的做法：把宽度、高度、dpi、字号体系、间距、线宽、字体族收进一个 `fig_spec()` 对象，让预览与保存读同一个对象；出图后用独立校验器解析 TIFF 的 IFD 标签，验证 LZW、dpi、物理尺寸是否真的达标，再逐像素量四边可见白边。

## 快速开始

```r
source("scripts/bootstrap.R")   # 唯一入口，不要直接 source fig_spec.R

spec <- fig_spec(journal = "nature", column = "single", content = "line")
# → 89 × 59.333 mm, 600 dpi, Arial
# → 字号自动取五级表：标题 8 / 副标题 7.5 / 轴标题 7 / 刻度 6.5 / 注释 5.5 pt

p <- ggplot(dt, aes(x, y, colour = grp)) +
  geom_line(linewidth = lw(1.0)) +              # 1.0 pt（已含 0.7528 折减补偿）
  geom_point(size = 1.2, stroke = lw(0.5)) +
  geom_text(aes(label = lab), size = pt(5.5)) + # 注意：不是 size = 7
  theme_pub(spec)

preview_pub(p, spec)                      # 与保存同参数渲染
save_pub(p, "output/fig01.tiff", spec)    # TIFF + LZW + 白底
check_tiff("output/fig01.tiff", spec)     # IFD：LZW/RGB/8bit/dpi/尺寸
check_margin("output/fig01.tiff", spec)   # 四边可见白边，逐像素
```

校验任意已有图件（不加载绘图栈，只需 base R）：

```bash
Rscript scripts/check_tiff_cli.R output/*.tiff --width 89 --dpi 600
Rscript scripts/check_tiff_cli.R output/*.tiff --json      # 供程序消费
```

## 四个致命单位陷阱

| 位置 | 单位 | 想写 8 pt |
|---|---|---|
| `theme(element_text(size = ))` | pt | `size = 8` |
| `geom_text()` / `annotate()` 的 `size` | **mm** | `size = pt(8)`；直接写 8 会得到约 22.7 pt |
| `linewidth` | **mm**，且只画出 0.7528 倍 | `linewidth = lw(0.75)` = 0.351，实得 0.75 pt |
| `margin()` 的默认单位 | **pt** | 1.5 mm 要写 `margin(4.252)` 或 `unit = "mm"` |

`linewidth` 的坑最隐蔽：写 `0.75 * 0.3528` 只得 0.56 pt，线普遍偏细 25%，而
`panel.border` 更狠——外侧一半被视口裁掉，只有名义值的 0.377 倍。

还有一个更隐蔽的：`ggsave(width = 7)` 默认单位是**英寸**，7 in ≈ 178 mm，你以为画了单栏，实际是双栏宽。

## 排版规范（v1.1）

完整推导、`[明文]/[实测]/[惯例]` 溯源与 21 组隔离实验见
[`references/typography-full.md`](references/typography-full.md)，速查版见
[`references/typography.md`](references/typography.md)，原始量测见
[`references/measurements.md`](references/measurements.md)。

**五级字号（绝对 pt，不随 `base_size` 缩放）**

| 层级 | 元素 | pt | 下限 |
|---|---|---|---|
| L1 | 图内标题（粗体） | 8 | 7 |
| L2 | 副标题、分面标题 | 7.5 | 6 |
| L3 | 轴标题、图例标题 | 7 | 6 |
| L3 | panel label（a/b/c） | 8 粗体 | 6 |
| L4 | 刻度标签、图例项 | 6.5 | 5 |
| L5 | 图内注释、数据标签、显著性标记 | 5.5 | 5 |

印刷绝对下限 5 pt；实际不要低于 6 pt；中文图内文字不低于六号（≈7.5 pt）。

**12 项间距（mm）**

| 项目 | 值 | 控制参数 |
|---|---|---|
| 四边留白 | 设定 1.7 → 可见 1.02–1.69 | `plot.margin` |
| 标题→副标题 | 1.3（两个 margin **相加**） | `plot.title` `margin(b)` + `plot.subtitle` `margin(t)` |
| 副标题→绘图区 | 1.5 | 仅 `plot.subtitle` 的 `margin(b)` |
| 刻度标签→轴线 | 0.6 | `axis.text.x/y` 的 `margin` |
| 刻度线长度 | 1.0 | `axis.ticks.length`（面板边缘起算） |
| 轴标题→刻度标签 | 1.0 margin → 约 1.55 可见 | `axis.title.x` 的 `margin(t)` |
| 图例标题→图例项 | 1.5 | `legend.title` 的 `margin(b)` |
| 图例项之间 | 字号 × 1.6 | **`legend.key.size`** |
| 图例框→绘图区 | 2.5 | `legend.box.spacing` |
| 多面板行/列间距 | 2.0 | `panel.spacing` |
| panel label→面板 | 0.5–1.0 | `plot.tag.position = c(0, 1)` |
| 标题左缘 | 对齐面板 | `plot.title.position = "panel"` |

**线宽（补偿后 `linewidth`，可直接抄）**

| 元素 | pt | `linewidth` |
|---|---|---|
| 轴线 / 刻度线 | 0.75 | 0.351 |
| 面板边框 | 0.75 | **0.702**（0.377 折减） |
| 数据线 / 拟合线 | 1.0 | 0.468 |
| 参考线 | 0.5 | 0.234 |
| 网格线（若保留） | 0.25 | 0.117 |
| 点边框 `stroke` | 0.5 | 0.234 |

**留白必须量像素，不能看参数。** `plot.margin = 1.0 mm` 的图，实测四边可见白边
只有 0.34 / 1.02 / 0.30 / 0.85 mm；原因是顶部刻度标签溢出 0.66 mm、数值定位的
tag 溢出 0.68 mm、轴线布局占位 0.15 mm。设 1.7 mm 才对应 1.06 / 1.69 / 1.02 /
1.57 mm，全部达标。

## 实测验证

R 4.3.3 / ggplot2 4.0.3 / ragg 1.3.2 / Windows 11，六张图真实运行（数据由 `check_tiff()` 从 IFD 反算，不是照抄参数）：

| 图 | 像素 | 物理尺寸 | dpi | 压缩 | 大小 |
|---|---|---|---|---|---|
| 折线 + 误差带 | 2102 × 1401 | 88.985 × 59.309 mm | 600 | LZW | 144 KB |
| 柱 + 散点 | 2102 × 1401 | 88.985 × 59.309 mm | 600 | LZW | 121 KB |
| 箱线 + 抖动 | 2102 × 1401 | 88.985 × 59.309 mm | 600 | LZW | 145 KB |
| 热图 | 2125 × 1594 | 89.958 × 67.479 mm | 600 | LZW | 276 KB |
| 多面板 A/B/C | 4200 × 2645 | 177.800 × 111.972 mm | 600 | LZW | 547 KB |
| 中文标注 | 1889 × 1417 | 79.968 × 59.986 mm | 600 | LZW | 77 KB |

全部：TIFF 版本 42、RGB、8/8/8 位、SamplesPerPixel=3、无 alpha、物理尺寸误差 < 0.05 mm。

**预览一致性**用"解码最终 LZW TIFF 的像素 vs 同 spec 预览 PNG 的像素"比对（LZW 无损，故等价于交付文件本身），结果 `max_channel_difference = 0`，差异像素 0。

**白边一致性**用 `check_margin()` 解码同一张 TIFF，取最外侧非白像素到画布边缘的距离，
判据四边均落在 1.0–2.0 mm。

## 仓库结构

```
SKILL.md                        # 工作流与硬规则（WorkBuddy / DSH 读这个）
scripts/
  bootstrap.R                   # 加载入口，修正 locale 后再 source
  fig_spec.R                    # 规格 / 主题 / 保存 / 预览 / TIFF 与白边校验
  check_tiff_cli.R              # 独立校验器，仅 base R
  examples.R                    # 六类图完整范例
  verify_pixels.R               # 像素级一致性证明
references/
  journal-specs.md              # 八家期刊栏宽/dpi/字号/线宽/字体
  typography.md                 # 排版细则速查（可执行版）
  typography-full.md            # 完整排版细则，逐条溯源 + 隔离实验
  measurements.md               # 排版量测报告（16 个量化陷阱）
  unit-traps.md                 # 单位换算与"预览≠保存"的六个根因
  troubleshooting.md            # 11 条实测踩坑
assets/paper_figure_guide.html  # 面向作者的完整图文指南
```

## 装到你的 Agent 里

| 宿主 | 安装方式 |
|---|---|
| **WorkBuddy** | 解压到 `~/.workbuddy/skills/r-paper-figures/` |
| **DSH** (DeepSeek Harness) | `cp -r . ~/.agents/skills/r-paper-figures/` |
| **opencode** | `.opencode/commands/r-figures.md`，正文用 `@path` 引用 `SKILL.md` |

opencode 的适配文件见 `integrations/opencode/`。

## 期刊规格

支持的预设：`nature` / `science` / `elsevier` / `acs` / `ieee` / `cn_gb`。

| 期刊 | 单栏 | 1.5 栏 | 双栏 |
|---|---|---|---|
| Nature | 89 mm | 136 mm | 183 mm |
| Science | 55 mm | 90 mm | 120 mm |
| Elsevier | 90 mm | 140 mm | 190 mm |
| ACS | 82.6 mm | — | 177.8 mm |
| IEEE | 88.9 mm | — | 181 mm |
| 中文期刊 | 80 mm | — | 170 mm |

> **规格会变**：同一出版社不同子刊栏宽可能相差 5–10 mm。投稿前必须以目标刊最新 Guide for Authors 为准。

## 边界

- R 只能输出 sRGB/RGB，需要 CMYK 时在外部转换（Photoshop / ImageMagick），转换后必须目视复核。
- TIFF 是位图，不存在字体嵌入问题，但文字不可编辑；期刊要求可编辑文字时需另附矢量版。
- 若目标刊明确"不接受 TIFF"或图为纯线条图，应改出 PDF/EPS，本仓库的 TIFF 参数不适用。

## License

MIT
