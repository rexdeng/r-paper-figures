---
name: r-paper-figures
display_name: R 科研论文图表规范出图
display_name_en: R Journal-Ready Figures
description: 论文配图、期刊投稿图、figure 规范、预览与保存不一致、dpi 分辨率、图件尺寸字号、TIFF+LZW、栏宽 89/90/183/190mm —— 用 R/ggplot2 输出符合期刊要求且预览即所得的科研图表，并校验 TIFF 是否合规。当用户要为论文出图、抱怨导出后尺寸/字号/字体变了、图表被期刊退回、或需要核对已有图件分辨率与压缩方式时使用。
whenToUse: 用户用 R 或 ggplot2 为论文/学位论文出图；提到期刊、投稿、见刊、figure、graphical abstract；抱怨预览与导出不一致；要求 TIFF、LZW、600 dpi、89mm/90mm/183mm/190mm 栏宽；需要校验已生成图件是否合规。
description_zh: 论文配图与期刊投稿图出图规范，用 R 输出符合期刊要求且预览即所得的图表，交付 TIFF+LZW 并校验 IFD 标签。
description_en: Journal-compliant scientific figures in R with pixel-exact preview/export parity, TIFF+LZW output, and IFD-level verification.
version: 1.0.0
agent_created: true
user-invocable: true
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
---

# R 科研论文图表规范出图

## 概述

解决一个具体问题：**RStudio 里看着正常的图，保存成文件后尺寸、字号、字体、线宽全不对**，导致投稿被退。

根因几乎从不是 R 的 bug，而是同一张图被两套参数渲染了两次——屏幕设备一套，文件设备一套。唯一可靠的解法是：把宽度、高度、dpi、基础字号、字体族收进一个规格对象，让预览与保存都读同一个对象。

产出目标是期刊可直接接收的位图：TIFF、LZW 无损压缩、8 位 RGB、白底无 alpha、物理尺寸精确等于目标栏宽。

## 何时使用

- 用户要为论文/学位论文出图，且明确提到期刊、投稿、见刊、figure、graphical abstract
- 用户抱怨"预览和导出不一致""保存后字号变了""图太大/太小"
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

p <- ggplot(dt, aes(x, y, colour = grp)) +
  geom_line(linewidth = lw(1.0)) +
  geom_point(size = 1.2) +
  theme_pub(spec)

preview_pub(p, spec)              # 与保存同参数渲染，屏幕 1:1 呈现
save_pub(p, "output/fig01.tiff", spec)
check_tiff("output/fig01.tiff", spec)
```

`fig_spec()` 的关键参数：

| 参数 | 取值 | 说明 |
|---|---|---|
| `journal` | nature / science / elsevier / acs / ieee / cn_gb | 决定栏宽与默认字体 |
| `column` | single / onehalf / double | 决定宽度 |
| `aspect` | 3:2 / 4:3 / custom | custom 时必须同时给 `height_mm` |
| `content` | line / combination / halftone / raster | line 与 combination 默认 600 dpi，halftone 300 |
| `dpi` | ≥ 300 | 覆盖 content 的默认值 |
| `base_size` | pt | 覆盖期刊默认字号 |
| `font_family` | 字体族名 | 覆盖期刊默认字体，中文用 SimSun/SimHei |

宽度不确定时不要猜，直接查 `references/journal-specs.md`。

绘图时必须遵守的统一约定：

- 文字尺寸一律 `size = pt(7)`，不写裸数字
- 线宽一律 `linewidth = lw(1.0)`
- 字体走 `spec$font_family`，不依赖默认 `sans`
- 抖动图用 `position_jitter(seed = 42)`，不用 `geom_jitter(..., seed = )`
- 图内不放图题（图题属正文图注）

现成范例见 `scripts/examples.R`（折线+误差带、柱+散点、箱线、热图、多面板、中文标注六类）。

### 步骤 4：校验并交付

```bash
Rscript scripts/check_tiff_cli.R output/*.tiff --width 89 --height 59.333 --dpi 600
```

校验项：字节序、TIFF 版本 42、Compression=5(LZW)、8/8/8 位、Photometric=2(RGB)、SamplesPerPixel=3、无 alpha、有效分辨率、物理尺寸误差 <0.5 mm、像素数与 mm×dpi 吻合（±1 px）。

全部 PASS 再交付。任一 FAIL，按 `references/troubleshooting.md` 对应条目排查。

需要向用户证明"预览=成品"时，跑 `scripts/verify_pixels.R`：它把最终 TIFF 的像素真正解码出来，与同 spec 的预览 PNG 逐像素比对，输出 `max_channel_difference` 与差异像素数。

## 三个致命单位陷阱

| 位置 | 单位 | 想写 8 pt |
|---|---|---|
| `theme(element_text(size = ))` | pt | `size = 8` |
| `geom_text()` / `annotate()` 的 `size` | **mm** | `size = pt(8)`，直接写 8 会得到 22.7 pt |
| `linewidth` | **mm** | `linewidth = lw(0.75)`，直接写 1 会得到 2.83 pt |

换算：`1 inch = 25.4 mm`，`1 pt = 0.352778 mm`，`1 mm = 2.845276 pt`。

第三处隐形陷阱：`ggsave(width = 7)` 默认单位是**英寸**，7 in = 177.8 mm，作者以为画了单栏实际是双栏。

## 格式边界

- R 只能输出 sRGB/RGB。需要 CMYK 时在外部转换（Photoshop 或 `magick convert in.tiff -colorspace CMYK out.tiff`），转换后必须目视复核，荧光色会变暗。
- TIFF 是位图，不存在字体嵌入问题，但文字不可编辑。Nature 等要求文字可编辑时，需同时提供矢量版。
- 若目标刊明确"不接受 TIFF"、或图为纯线条图，应改出 PDF/EPS，本技能的 TIFF 参数不适用。
- 不要启用 `showtext`：它接管文本栅格化，与 ragg 经 systemfonts/textshaping 的解析路径冲突，是预览与输出字形不一致的隐形元凶。

## 常见误诊

| 用户描述 | 实际原因 | 处置 |
|---|---|---|
| "保存后字号变大了" | `geom_text(size = 8)` 单位是 mm | 改 `pt(8)` |
| "预览图例两行，导出三行" | 字体未绑定，字宽变了 | 显式 `font_family` |
| "图比想象中宽" | `ggsave` 默认英寸 | 显式 `units = "mm"` |
| "散点位置对不上" | jitter 每次重抽 | `position_jitter(seed = 42)` |
| "分辨率不够" | 先出小图再标高 dpi | 先定 mm+dpi 让设备算像素 |
| "文件太大被拒" | 压缩没生效或 dpi 过高 | 查 tag 259 与 dpi |

## 资源

- `scripts/bootstrap.R` — **加载入口**。修正 locale 后用 UTF-8 载入 `fig_spec.R`；纯 ASCII，本身在任何 locale 下都能被 source。直接运行会打印 R 版本、locale、依赖包版本与 `fig_spec()` 签名，用于快速体检。
- `scripts/fig_spec.R` — 核心模块：`fig_spec()` / `theme_pub()` / `save_pub()` / `preview_pub()` / `preview_pair()` / `check_tiff()` / `pt()` / `lw()` / `register_cjk_font()` / `read_tiff_pixels()`。TIFF 解析与 LZW 解码均为 base R 实现，不依赖 magick/tiff/Cairo。
- `scripts/check_tiff_cli.R` — 独立命令行校验器，仅依赖 base R，可对任意 TIFF 批量校验，支持 `--json` 输出，退出码 0/1 可用于 CI。
- `scripts/examples.R` — 六类图的完整可运行范例（折线+误差带、柱+散点、箱线、热图、多面板、中文标注）。
- `scripts/verify_pixels.R` — 像素级一致性验证，解码最终 TIFF 与预览 PNG 逐像素比对，证明预览即成品。
- `references/journal-specs.md` — 八家期刊/出版社的栏宽、dpi、字号、线宽、字体对照表与常见误判。
- `references/unit-traps.md` — 单位换算基准与"预览≠保存"的六个根因机制。
- `references/troubleshooting.md` — 十个实测踩坑（patchwork×ggplot2 4.0、像素取整、jitter 种子、locale、退出段错误等）的现象/原因/做法。
- `assets/paper_figure_guide.html` — 面向作者的完整图文指南，可直接交付给用户阅读或打印。
