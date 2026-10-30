# 期刊图形规格速查表

本表是 `fig_spec()` 预设的数据来源。数字来自各出版社的 Guide for Authors / Artwork Guidelines，**但期刊规格会随年份调整，且同一出版社不同子刊栏宽可能相差 5–10 mm**。投稿前必须复核目标刊当前版本。

## 一、栏宽与版心（单位 mm）

| 期刊 / 出版社 | 单栏 | 1.5 栏 | 双栏 | 最大高度 | 备注 |
|---|---|---|---|---|---|
| Nature | 89 | 120–136 | 183 | 170（印刷版心） | 图片区另有 89 × 110 的紧凑要求 |
| Science (AAAS) | 55 | — | 120（全页 183） | — | 三栏布局，55 mm 是真正的窄单栏 |
| Elsevier | 90 | 140 | 190 | 220–250（因刊而异） | 官方明确 2500+ 期刊栏宽不统一 |
| Cell Press | 85 | — | 174 | 235 | — |
| ACS | 82.6（3.25 in） | — | 177.8（7 in） | — | 英寸制的典型代表 |
| IEEE | 88.9（3.5 in） | — | 181（7.16 in） | — | 双栏刊为主 |
| PNAS | 87 | — | 178 | 230 | — |
| 中文期刊（GB/T 7713 惯例） | 80 | — | 170 | — | 各刊自行规定，80/170 是常见值 |

`fig_spec()` 中的 `onehalf` 对未明确公布的期刊取单双栏中间值，属于估计值——代码注释里标了 `[est]`。若目标刊没有 1.5 栏概念，不要用这个档。

## 二、分辨率（按图像内容类型，而非按期刊）

这是最容易搞错的一档：**要求取决于图里有没有半色调**，不是"这个刊要求 600 dpi"。

| 内容类型 | Elsevier | Nature | ACS / IEEE | 通用下限 |
|---|---|---|---|---|
| 线条图（line art，纯色块与线） | 1000 dpi | 600 dpi | 600 dpi | 600 dpi |
| 组合图（线 + 半色调） | 500 dpi | 600 dpi | 600 dpi | 500 dpi |
| 半色调（照片、渐变、热图插值） | 300 dpi | 300 dpi | 300 dpi | 300 dpi |

`fig_spec(content = )` 的映射：

- `content = "line"` 或 `"combination"` → 默认 600 dpi
- `content = "halftone"` → 默认 300 dpi

不要为了"保险"一律上 1000 dpi：190 × 250 mm 在 1000 dpi 下是 7480 × 9843 px，未压缩约 220 MB，多数投稿系统会直接拒收。

## 三、字号

| 期刊 | 图内正文 | 最小允许 | panel label |
|---|---|---|---|
| Nature | 5–7 pt | 5 pt | 8 pt bold |
| Science | 6–8 pt | 6 pt | 同正文加粗 |
| Elsevier | 7 pt | 5 pt（上下标 6 pt） | 8 pt bold |
| Cell Press | ≥ 6 pt | 6 pt | — |
| ACS | 4.5–12 pt | 4.5 pt | — |
| IEEE | 8–10 pt | 8 pt | — |
| PNAS | 6–12 pt | 6 pt | — |
| 中文期刊 | 7–9 pt（六号 7.5 / 小五 9） | 7 pt | 黑体加粗 |

**关键约束：图内字号应与你正文最终印刷字号相当或略小。** 期刊把图缩放到栏宽后，字号是等比例缩小的——按 190 mm 设计、最终印在 90 mm 单栏，8 pt 会变成 3.8 pt，直接不合规。所以必须**按最终栏宽出图**，不要"画大图再缩小"。

## 四、线宽

| 期刊 | 轴线 | 数据线 | 绝对下限 |
|---|---|---|---|
| Nature | 0.25–1 pt | 0.5–1 pt | 0.25 pt |
| Elsevier | 0.5–1.5 pt | 约 1 pt | 0.25 pt |
| ACS | ≥ 0.5 pt | — | 0.5 pt |
| 中文期刊 | ≥ 0.5 pt | — | 0.5 pt |

实践值：轴线 0.75 pt、数据线 1.0 pt、误差棒 0.75 pt、网格线 0.25–0.5 pt（若保留）。低于 0.25 pt 的线在 600 dpi 下只有约 2 px，印刷会断线或消失。

## 五、字体

| 期刊 | 允许字体 | 说明 |
|---|---|---|
| Nature | Arial / Helvetica | 明确要求 sans-serif |
| Science | Helvetica 优先 | — |
| Elsevier | Arial, Helvetica, Times, Symbol | Symbol 用于希腊字母与数学符号 |
| Cell Press | Arial / Helvetica | — |
| ACS | Arial / Helvetica / Times | — |
| IEEE | Times New Roman | 少数要求 serif 的主流刊 |
| PNAS | sans-serif | — |
| 中文期刊 | 正文宋体（SimSun），标题黑体（SimHei），英文与数字 Times New Roman | 中英混排时数字用 Times 更规范 |

`fig_spec()` 的默认值：Nature / Science / Elsevier / ACS → `Arial`；IEEE → `Times New Roman`；`cn_gb` → `SimSun`。

**不要用默认 `sans`**：Windows 上解析为 Arial，PDF 设备解析为 Helvetica，ragg 走 systemfonts 再解析一次，三处字宽不同，会导致文本溢出和图例换行位置变化。

## 六、格式与色彩

| 项目 | 要求 |
|---|---|
| 位图格式 | TIFF（多数刊接受）、PNG（部分接受）；EPS/PDF 用于矢量线条图 |
| 压缩 | LZW 无损；Elsevier 明确要求 flatten layers + LZW |
| 位深 | 8 位/通道（16 位仅在明确要求时用，文件体积翻倍） |
| 色彩模式 | RGB；需 CMYK 时投稿系统或编辑部转换，或自行在 Photoshop/ImageMagick 转 |
| 背景 | 白色、不透明。**alpha 通道会被判不合规** |
| 单图体积上限 | Elsevier 常见 40 MB；Nature 主图建议 ≤ 50 MB |
| 字体嵌入 | TIFF 是位图，不存在嵌入问题；但文字不可编辑，Nature 等要求可编辑文字时需另附矢量版 |

Nature 对线条图偏好矢量（EPS/PDF/AI），TIFF 主要留给照片类图。若目标刊明确"不接受 TIFF"，本技能的 TIFF 路线不适用，应改出 PDF/EPS。

## 七、常见误判

1. **把 89 mm 当"差不多 90"**：Nature 单栏 89 mm 出图后若被 Elsevier 按 90 mm 排版，缩放 1.1%，肉眼无感但比例尺与字号会略微失准。跨刊转投时重出图，不要复用。
2. **双栏宽用 183 vs 190**：Nature 183 / Elsevier 190 差 7 mm，按 190 出图投 Nature 会被缩到 96.3%，字号随之缩水。
3. **忽略最大高度**：宽度对了但高度超版心，排版时会被强制缩放，等于白做。
4. **图注写进图内**：图题、方法说明必须放正文图注，图内只留必要的轴标签、图例、panel label。
