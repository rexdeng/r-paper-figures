---
name: r-paper-figures
display_name: R 科研论文图表规范出图
display_name_en: R Journal-Ready Figures
description: 论文配图、期刊投稿图、figure 规范、预览与保存不一致、dpi 分辨率、图件尺寸字号、字号分级、行间距、图例间距、四周留白、线条粗细、TIFF+LZW、栏宽 89/90/183/190mm —— 用 R/ggplot2 输出符合期刊要求且预览即所得的科研图表，按五级字号/12 项间距/补偿线宽落地，并校验 TIFF 与可见白边。当用户要为论文出图、抱怨导出后尺寸/字号/字体变了、图表被期刊退回、觉得图"挤"或"空"、或需要核对已有图件分辨率、压缩方式与留白时使用。
whenToUse: 用户用 R 或 ggplot2 为论文/学位论文出图；提到期刊、投稿、见刊、figure、graphical abstract；抱怨预览与导出不一致；要求 TIFF、LZW、600 dpi、89mm/90mm/183mm/190mm 栏宽；要调字号、行距、图例间距、轴标题距离、线宽、四周留白；需要校验已生成图件是否合规。
description_zh: 论文配图与期刊投稿图出图规范，用 R 输出符合期刊要求且预览即所得的图表，含五级字号、间距、线宽补偿与留白验收，交付 TIFF+LZW 并校验 IFD 标签。
description_en: Journal-compliant scientific figures in R with pixel-exact preview/export parity, a five-level type scale, spacing/line-width rules, TIFF+LZW output, and IFD-level verification.
version: 1.1.0
agent_created: true
user-invocable: true
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
---

# R 科研论文图表规范出图

## 概述

解决一个具体问题：**RStudio 里看着正常的图，保存成文件后尺寸、字号、字体、线宽全不对**，导致投稿被退。

根因几乎从不是 R 的 bug，而是同一张图被两套参数渲染了两次——屏幕设备一套，文件设备一套。唯一可靠的解法是：把宽度、高度、dpi、基础字号、字体族收进一个规格对象，让预览与保存都读同一个对象。

产出目标是期刊可直接接收的位图：TIFF、LZW 无损压缩、8 位 RGB、白底无 alpha、物理尺寸精确等于目标栏宽。

v1.1 起，`theme_pub()` 已内置完整的**五级字号、12 项间距、补偿线宽**，不再需要手工调 `base_size` 与 margin。排版数值的推导、实测与冲突说明见 `references/typography.md`（速查）与 `references/typography-full.md`（完整细则）。

## 何时使用

- 用户要为论文/学位论文出图，且明确提到期刊、投稿、见刊、figure、graphical abstract
- 用户抱怨"预览和导出不一致""保存后字号变了""图太大/太小"
- 用户抱怨图"太挤""太空""字太小""线太细""白边被裁"，要调字号、行距、图例间距、轴标题距离、线宽、四周留白
- 用户要求 TIFF、LZW、600 dpi、栏宽 89 mm / 90 mm / 183 mm / 190 mm 等具体规格
- 用户已有图件，需要核对是否合规（此时直接用 `scripts/check_tiff_cli.R`，不必重画）
- 用户要中文标注的期刊图（宋体/黑体）

不适用：网页/看板/PPT 用图（无需印刷规格）；纯矢量 EPS/PDF 投稿（本技能给的是位图路线，见下方"格式边界"）。

## 核心原则（不可妥协的三条）

1. **一个 spec 驱动两个设备**。预览与保存的 `width/height/dpi/font_family/base_size` 必须来自同一个对象，不允许预览用窗口尺寸、保存用另一套参数。
2. **按最终栏宽出图**。不要"出大图再缩"——缩图会让字号等比缩小，8 pt 印成 3.8 pt。
3. **校验读文件，不读记忆**。是否 600 dpi、是否 LZW、物理尺寸多少，一律解析 TIFF 的 IFD 标签，不接受"我记得设了"。

## 工作流

### 步骤 1：确定目标规格

先问清三件事，缺一不可：

- **目标期刊**（决定栏宽与字体）→ 查 `references/journal-specs.md`
- **单栏 / 1.5 栏 / 双栏**
- **图的内容类型**：线条/组合（600 dpi）还是半色调（300 dpi）

不要凭印象填栏宽。Nature 89、Science 55、Elsevier 90/140/190、ACS 82.6/177.8、IEEE 88.9/181、中文刊 80/170 —— 这些值都在参考表里，且必须提醒用户**以目标刊最新 Guide for Authors 为准**。

### 步骤 2：定位 R 环境

先探测，不要假设路径存在：

```bash
which Rscript || ls -d /d/R/*/bin /c/Program\ Files/R/*/bin 2>/dev/null
```

Windows 上可查注册表 `HKLM:\SOFTWARE\R-core\R` 的 `InstallPath`。确认三个关键包：

```bash
Rscript -e 'for (p in c("ggplot2","ragg","systemfonts")) cat(p, requireNamespace(p, quietly=TRUE), "\n")'
```

`ragg` 缺失时先装：`install.packages("ragg")`。**不要退回到 `grDevices::tiff()`**——它的字体与抗锯齿路径和屏幕差异大，正是"预览不一致"的来源之一。

### 步骤 3：出图

把 `scripts/` 目录复制到用户项目，或直接用绝对路径 source。**入口一律用 `bootstrap.R`，不要直接 source `fig_spec.R`**——后者含中文注释，在 C locale 下 `source(encoding = "UTF-8")` 会失败，函数根本没被定义，报错却是 "could not find function"，极难定位。`bootstrap.R` 已内置 locale 修正。

```r
source("scripts/bootstrap.R")   # 注意：不要加 encoding 参数

spec <- fig_spec(journal = "nature", column = "single", content = "line")
# nature + single + 3:2 → 89 × 59.333 mm, 600 dpi, 7 pt, Arial
# 字号取 TYPE_SCALE 绝对值：标题 8 / 副标题 7.5 / 轴标题 7 / 刻度 6.5 / 注释 5.5

p <- ggplot(dt, aes(x, y, colour = grp)) +
  geom_line(linewidth = lw(1.0)) +      # 1.0 pt（已含 0.7528 折减补偿）
  geom_point(size = 1.2) +
  theme_pub(spec)

preview_pub(p, spec)              # 与保存同参数渲染，屏幕 1:1 呈现
save_pub(p, "output/fig01.tiff", spec)
check_tiff("output/fig01.tiff", spec)     # IFD：LZW/RGB/8bit/dpi/尺寸
check_margin("output/fig01.tiff", spec)   # 四边可见白边，逐像素
```

`fig_spec()` 的关键参数：

| 参数 | 取值 | 说明 |
|---|---|---|
| `journal` | nature / science / elsevier / acs / ieee / cn_gb | 决定栏宽与默认字体 |
| `column` | single / onehalf / double | 决定宽度 |
| `aspect` | 3:2 / 4:3 / custom | custom 时必须同时给 `height_mm` |
| `content` | line / combination / halftone / raster | line 与 combination 默认 600 dpi，halftone 300 |
| `dpi` | ≥ 300 | 覆盖 content 的默认值 |
| `base_size` | pt | 只定设备基准，**不决定最终字号**（见 §3.3 相对字号陷阱） |
| `sizes` | 命名向量 | 覆盖 `TYPE_SCALE`，如 `c(axis_text = 6, tag = 10)` |
| `margin_mm` | 默认 1.7 | 对应可见白边 ≥1.0 mm；紧裁可降 1.3（可见 0.65，有风险） |
| `tick_length_mm` | 默认 1.0 | 从面板边缘起算的全长；中文刊用 `tick_direction = "in"` |
| `grid` | 默认 FALSE | TRUE 给 0.25 pt 极淡主网格 |
| `border` | 默认 FALSE | TRUE 给完整面板边框（已按 0.377 折减补偿） |
| `font_family` | 字体族名 | 覆盖期刊默认字体，中文用 SimSun/SimHei |

宽度不确定时不要猜，直接查 `references/journal-specs.md`。

绘图时必须遵守的统一约定：

- 文字尺寸一律 `size = pt(5.5)`，不写裸数字（`geom_text` 的 size 是 mm）
- 线宽一律 `linewidth = lw(1.0)`，它返回 `pt × 0.4679`；面板边框用 `lwb(0.75)`
- 字体走 `spec$font_family`，不依赖默认 `sans`
- 抖动图用 `position_jitter(seed = 42)`，不用 `geom_jitter(..., seed = )`
- 图内不放图题（图题属正文图注）；学位论文要标题时用 L1 8 pt 粗体
- 多面板拼图把相邻侧的 `plot.margin` 压到 1.0 mm，否则间距 = 3.4 mm 超上限

现成范例见 `scripts/examples.R`（折线+误差带、柱+散点、箱线、热图、多面板、中文标注六类）。

### 步骤 4：校验并交付

```bash
Rscript scripts/check_tiff_cli.R output/*.tiff --width 89 --height 59.333 --dpi 600
```

校验项：字节序、TIFF 版本 42、Compression=5(LZW)、8/8/8 位、Photometric=2(RGB)、SamplesPerPixel=3、无 alpha、有效分辨率、物理尺寸误差 <0.5 mm、像素数与 mm×dpi 吻合（±1 px）。

全部 PASS 再交付。任一 FAIL，按 `references/troubleshooting.md` 对应条目排查。

再验一次**可见白边**——这是投稿被退最高频、也最容易被"代码里写了 1.7 mm"骗过的一项：

```r
check_margin("output/fig01.tiff", spec)   # 四边可见白边，判据 1.0–2.0 mm
```

`check_margin()` 直接解码像素（TIFF 走自带 LZW 解码器，约 2 s/张），取最外侧
非白像素到画布边缘的距离。它和 `plot.margin` 不是一回事：顶部刻度标签会吃掉
0.66 mm、数值定位的 tag 吃掉 0.68 mm、轴线布局占位吃掉 0.15 mm。

需要向用户证明"预览=成品"时，跑 `scripts/verify_pixels.R`：它把最终 TIFF 的像素真正解码出来，与同 spec 的预览 PNG 逐像素比对，输出 `max_channel_difference` 与差异像素数。

## 四个致命单位陷阱

| 位置 | 单位 | 想写 8 pt |
|---|---|---|
| `theme(element_text(size = ))` | pt | `size = 8` |
| `geom_text()` / `annotate()` 的 `size` | **mm** | `size = pt(8)`，直接写 8 会得到 22.7 pt |
| `linewidth` | **mm**，且只画出 0.7528 倍 | `linewidth = lw(0.75)` = 0.351，实得 0.75 pt |
| `margin()` 的默认单位 | **pt** | 1.5 mm 要写 `margin(4.252)` 或 `unit = "mm"` |

换算：`1 inch = 25.4 mm`，`1 pt = 0.352778 mm`，`1 mm = 2.845276 pt`。

第三处的补偿量：`0.75 × 0.3528 = 0.265` 只画出 0.56 pt，看起来"线怎么这么细"。
本技能的 `lw()` 返回 `T × 0.4679`；`panel.border` 因外侧一半被裁，还要 `lwb()` 再乘 2。

第四处隐形陷阱：`ggsave(width = 7)` 默认单位是**英寸**，7 in = 177.8 mm，
作者以为画了单栏实际是双栏。

## 排版速查（`theme_pub()` 已内置，只在要偏离时才手动改）

**五级字号（绝对 pt，不随 base_size 缩放）**

| 层级 | 元素 | pt | 下限 |
|---|---|---|---|
| L1 | 图内标题（粗体） | 8 | 7 |
| L2 | 副标题、分面标题 | 7.5 | 6 |
| L3 | 轴标题、图例标题、panel label | 7 / 8 | 6 |
| L4 | 刻度标签、图例项 | 6.5 | 5 |
| L5 | 图内注释、数据标签、显著性标记 | 5.5 | 5 |

印刷绝对下限 5 pt；实际不要低于 6 pt；中文图内文字不低于六号（≈7.5 pt）。

**12 项间距（mm）**

| 项目 | 值 | 控制参数 |
|---|---|---|
| 四边留白（设定） | 1.7 → 可见 1.02–1.69 | `plot.margin` |
| 标题→副标题 | 1.3（两个 margin **相加**） | `plot.title` `margin(b)` + `plot.subtitle` `margin(t)` |
| 副标题→绘图区 | 1.5 | 仅 `plot.subtitle` 的 `margin(b)` |
| 刻度标签→轴线 | 0.6 | `axis.text.x/y` 的 `margin` |
| 刻度线长度 | 1.0 | `axis.ticks.length`（面板边缘起算，负值向内） |
| 轴标题→刻度标签 | 1.0 margin → 约 1.55 可见 | `axis.title.x` 的 `margin(t)`（+0.55 固定余量） |
| 图例标题→图例项 | 1.5 | `legend.title` 的 `margin(b)` |
| 图例项之间 | 字号 × 1.6 | **`legend.key.size`**（`legend.spacing.y` 无效） |
| 图例框→绘图区 | 2.5 | `legend.box.spacing`（会压窄面板） |
| 多面板行/列间距 | 2.0 | `panel.spacing`；patchwork 用 `plot.margin` 之和 |
| panel label→面板 | 0.5–1.0 | `plot.tag` + `plot.tag.position = c(0, 1)` |
| 标题左缘 | 对齐面板 | `plot.title.position = "panel"` |

完整推导、陷阱成因与 18 条验收判据见 `references/typography.md`。

## 格式边界

- R 只能输出 sRGB/RGB。需要 CMYK 时在外部转换（Photoshop 或 `magick convert in.tiff -colorspace CMYK out.tiff`），转换后必须目视复核，荧光色会变暗。
- TIFF 是位图，不存在字体嵌入问题，但文字不可编辑。Nature 等要求文字可编辑时，需同时提供矢量版。
- 若目标刊明确"不接受 TIFF"、或图为纯线条图，应改出 PDF/EPS，本技能的 TIFF 参数不适用。
- 不要启用 `showtext`：它接管文本栅格化，与 ragg 经 systemfonts/textshaping 的解析路径冲突，是预览与输出字形不一致的隐形元凶。

## 常见误诊

| 用户描述 | 实际原因 | 处置 |
|---|---|---|
| "保存后字号变大了" | `geom_text(size = 8)` 单位是 mm | 改 `pt(5.5)` |
| "线怎么这么细" | `linewidth` 只画出名义值的 0.75 | 用 `lw(T)`（补偿到 `T×0.4679`） |
| "四周白边不够 / 被裁" | `plot.margin` ≠ 可见白边 | 设 1.7 mm，用 `check_margin()` 验 |
| "图例项挤在一起" | 调了 `legend.spacing.y`（对它无效） | 调 `legend.key.size`（字号 × 1.6） |
| "调图例间距结果图变窄了" | `legend.box.spacing` 压的是面板宽度 | 接受面板变窄，或缩图例（改列数/字号） |
| "标题离副标题太远" | 两个 margin 相加 + 0.59 mm 固定余量 | 合计压到 0.5–0.9 mm |
| "预览图例两行，导出三行" | 字体未绑定，字宽变了 | 显式 `font_family` |
| "图比想象中宽" | `ggsave` 默认英寸 | 显式 `units = "mm"` |
| "散点位置对不上" | jitter 每次重抽 | `position_jitter(seed = 42)` |
| "分辨率不够" | 先出小图再标高 dpi | 先定 mm+dpi 让设备算像素 |
| "文件太大被拒" | 压缩没生效或 dpi 过高 | 查 tag 259 与 dpi |

## 资源

- `scripts/bootstrap.R` — **加载入口**。修正 locale 后用 UTF-8 载入 `fig_spec.R`；纯 ASCII，本身在任何 locale 下都能被 source。直接运行会打印 R 版本、locale、依赖包版本与 `fig_spec()` 签名，用于快速体检。
- `scripts/fig_spec.R` — 核心模块：`fig_spec()` / `theme_pub()` / `save_pub()` / `preview_pub()` / `preview_pair()` / `check_tiff()` / `check_margin()` / `pt()` / `lw()` / `lwb()` / `register_cjk_font()` / `read_tiff_pixels()`，以及字号常量 `TYPE_SCALE`、线宽常量 `PT2LW` / `PT2LW_BDR`。TIFF 解析与 LZW 解码均为 base R 实现，不依赖 magick/tiff/Cairo。
- `scripts/check_tiff_cli.R` — 独立命令行校验器，仅依赖 base R，可对任意 TIFF 批量校验，支持 `--json` 输出，退出码 0/1 可用于 CI。
- `scripts/examples.R` — 六类图的完整可运行范例（折线+误差带、柱+散点、箱线、热图、多面板、中文标注）。
- `scripts/verify_pixels.R` — 像素级一致性验证，解码最终 TIFF 与预览 PNG 逐像素比对，证明预览即成品。
- `references/journal-specs.md` — 八家期刊/出版社的栏宽、dpi、字号、线宽、字体对照表与常见误判。
- `references/typography.md` — **排版细则速查（可执行版）**：五级字号、12 项间距、线宽补偿表、18 条验收判据、六条待定项的建议默认值。
- `references/typography-full.md` — 完整排版细则（约 5 万字）：逐条 `[明文]/[实测]/[惯例]` 溯源、21 组隔离实验、冲突与取舍。
- `references/measurements.md` — 排版量测报告：16 个量化陷阱的原始实验数据、复现脚本说明、与直觉相反的结论。
- `references/unit-traps.md` — 单位换算基准与"预览≠保存"的六个根因机制。
- `references/troubleshooting.md` — 十个实测踩坑（patchwork×ggplot2 4.0、像素取整、jitter 种子、locale、退出段错误等）的现象/原因/做法。
- `assets/paper_figure_guide.html` — 面向作者的图文指南（讲"为什么预览会骗你"与操作流程）；**具体排版数值以 `references/typography.md` 为准**，该 HTML 未覆盖 v1.1 的五级字号与间距表。
