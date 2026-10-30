# 追加到项目根目录的 AGENTS.md（或 ~/.config/opencode/AGENTS.md）

## 论文配图 / 期刊出图

当任务涉及为论文、学位论文、期刊投稿绘制或核对图表时，先读
`.opencode/r-paper-figures/SKILL.md`，按其工作流执行；细则在 `references/`：

- 期刊栏宽 / dpi / 字号 / 线宽 / 字体 → `references/journal-specs.md`
- 单位换算与"预览≠保存"根因 → `references/unit-traps.md`
- 报错与异常排查 → `references/troubleshooting.md`

三条不可妥协的规则：

1. 预览与保存必须由同一个 `fig_spec()` 对象驱动，不允许预览看窗口尺寸、保存另给参数。
2. `geom_text()` / `annotate()` 的 `size` 单位是 **mm** 不是 pt，写 8 pt 必须 `size = pt(8)`；`linewidth` 单位是 mm，0.75 pt 必须 `lw(0.75)`。
3. 交付前必须用 `scripts/check_tiff_cli.R` 校验实际文件的 IFD 标签（LZW、dpi、物理尺寸），不接受"我记得设了"。

加载核心模块统一走 `source(".opencode/r-paper-figures/scripts/bootstrap.R")`。
