---
description: 按期刊规范出 R 论文图（预览即所得 + TIFF/LZW 校验）
agent: build
---

先完整读取 @.opencode/r-paper-figures/SKILL.md，严格按其中的工作流执行，不要凭记忆改写参数。

用户需求：$ARGUMENTS

执行要点（SKILL.md 里有完整细节，此处仅作硬约束）：

1. 先确认三件事再动手：目标期刊、单栏/双栏、图的内容类型（线条 or 半色调）。缺哪项就问，不要猜栏宽。
2. 定位 Rscript（`which Rscript`，Windows 可查 `D:/R/*/bin` 或 `C:/Program Files/R/*/bin`），确认 ggplot2 / ragg / systemfonts 已装。
3. 用 `source(".opencode/r-paper-figures/scripts/bootstrap.R")` 加载核心模块。不要直接 source `fig_spec.R`——它含中文注释，在 C locale 下会解析失败，报错却是 "could not find function"。
4. 出图必须：`fig_spec(journal=, column=, content=)` 一个对象同时驱动预览与保存；文字 `size = pt(7)`；线宽 `linewidth = lw(1.0)`；抖动用 `position_jitter(seed = 42)`。
5. 出图后用 `Rscript .opencode/r-paper-figures/scripts/check_tiff_cli.R <files> --dpi 600` 校验，全部 PASS 才交付。失败项查 @.opencode/r-paper-figures/references/troubleshooting.md。

期刊规格查 @.opencode/r-paper-figures/references/journal-specs.md，不要凭印象填数字；并在交付时提醒用户以目标刊最新 Guide for Authors 为准。
