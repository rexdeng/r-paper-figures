# 实测踩坑与排查手册

以下每条都在真实环境复现过（R 4.3.3 / ggplot2 4.0.3 / ragg 1.3.2 / patchwork 1.3.0 / Windows 11）。

---

## 1. `patchwork & theme` 报 "Can't find method for generic &"

**现象**

```
Error in `&.gg()`:
! Can't find method for generic `&`
```

**原因**：ggplot2 4.0 改用 S7 对象体系，`theme` 的类与方法分派变了；patchwork 1.3.0 的 `&` 运算符仍按 S3 查找 `&.gg` 方法，找不到就报错。这是版本组合问题，不是代码写错。

**做法**：不要用 `& theme_pub()` 给整组图统一主题，改为对每个子图单独加主题后再组合。

```r
# 不可用
p1 + p2 + p3 & theme_pub(spec)

# 可用
(p1 + theme_pub(spec)) + (p2 + theme_pub(spec)) + (p3 + theme_pub(spec))
```

代价是主体代码重复。可先用 `lapply` 批量套主题再 `wrap_plots()`：

```r
plots <- lapply(list(p1, p2, p3), function(p) p + theme_pub(spec))
patchwork::wrap_plots(plots, ncol = 3) + patchwork::plot_annotation(tag_levels = "A")
```

---

## 2. 输出像素比 `mm/25.4*dpi` 少 1 px

**现象**：89 mm @ 600 dpi → 期望 2102.36 px，实际得到 2102 px（正常）；但 59.333 mm → 期望 1401.57，实际 1401（正常），而某些高度会少 1 px。

**原因**：ragg 用 `floor(mm/25.4*dpi)` 取整，不是四舍五入。

**做法**：校验时用 `floor()` 而非 `round()`，并允许 ±1 px 容差。因为人工输入的 mm 常被四舍五入（写 59.3 而非 59.333），floor 结果就差 1 px——1 px 在 600 dpi 下是 0.04 mm，不影响合规。`check_tiff_cli.R` 已按 ±1 px 判定。

```r
expected_px <- floor(width_mm / 25.4 * dpi + 1e-9)
```

---

## 3. `geom_jitter()` 写了 `seed` 但每次位置还是不同

**现象**：预览与保存的散点位置不一致，逐像素比对有 0.3% 差异。

**原因**：`geom_jitter()` 的参数表里没有 `seed`，多余的参数被静默吞掉，不报错。随机数在每次 draw 时重新抽。

**做法**：改用 `position_jitter()`，它支持 `seed`。

```r
# 无效
geom_jitter(width = 0.08, seed = 42)

# 有效
geom_point(position = position_jitter(width = 0.08, height = 0, seed = 42))
```

同理，`ggbeeswarm::geom_beeswarm()` 也需固定随机种子或改用确定性布局。

---

## 4. 退出时 `Segmentation fault` / 退出码 139（0xC0000005）

**现象**：脚本全部执行完、文件全部写出、校验全部 PASS，但进程退出时报段错误。

**原因**：在某些 Windows 沙箱/宿主环境里，只要加载 `cli`（ggplot2 的依赖链）就会在进程清理阶段崩溃。最小复现：

```bash
Rscript -e "requireNamespace('cli'); cat('ok\n')"
```

**判断方法**：看文件是否完整落盘、`check_tiff()` 是否通过。若都正常，则这是宿主环境问题，不是脚本逻辑问题。

**做法**：

1. 在普通终端（非受限沙箱）复验退出码；
2. 把校验与出图拆成两个进程——出图脚本可能崩，但 `check_tiff_cli.R` 只依赖 base R，不受影响；
3. 不要把退出码当作"是否成功"的唯一依据，改为以输出文件的 IFD 校验为准。

---

## 5. 没有 magick / tiff / Cairo 包，如何验证 TIFF

**现象**：`library(magick)` 报 there is no package called 'magick'；`Add-Type -AssemblyName System.Drawing` 被安全策略拦截。

**做法**：用 base R `readBin()` 自己解析 TIFF header 与 IFD。这反而是更可信的验证——不依赖任何第三方库的解读。

可直接调用：

```bash
Rscript scripts/check_tiff_cli.R output/*.tiff --width 89 --dpi 600
```

需要读像素时，`fig_spec.R` 里的 `read_tiff_pixels()` 已实现 IFD 解析 + TIFF LZW 解码（约 130 行）。要点：

- 4 字节整数不能用 `readBin(signed = FALSE)`（base R 只对 1/2 字节有效），要先按有符号读再 `+ 2^32` 补回；
- 大于 4 字节的值（如多通道 `BitsPerSample`）在 IFD 条目里存的是**偏移量**，要再 seek 一次；
- RATIONAL 类型（分辨率）是两个 LONG，前分子后分母。

---

## 6. `LC_*` locale 警告与 `source(encoding = "UTF-8")` 报错

**现象**

```
Warning: Setting LC_CTYPE failed, using "C"
Error in source(...): invalid input found on input connection
```

**原因**：宿主把 `LC_ALL` 设成 `C.UTF-8`，Windows 的 R 不认这个 locale 名，回退到 C，于是含中文的 UTF-8 源文件在读取时被判非法字节。

**做法**：用 `scripts/bootstrap.R` 作为唯一加载入口——它先把 locale 切到系统认识的名字，再以 UTF-8 载入 `fig_spec.R`，且文件本身是纯 ASCII，所以在任何 locale 下都能被 source。

```r
source("scripts/bootstrap.R")     # 不要加 encoding 参数
```

若自己写加载逻辑，注意顺序陷阱：`Sys.setlocale()` 必须写在 `source()` **之前**，且不能放在被加载文件内部——`source()` 是先整体解析再执行，放在里面等于没放。

```r
# 正确
try(Sys.setlocale("LC_ALL", "English_United States.utf8"), silent = TRUE)
source("fig_spec.R", encoding = "UTF-8")

# 错误：locale 在文件内设置，解析阶段已经失败了
```

输出 UTF-8 报告时显式指定连接编码：`file(path, encoding = "UTF-8")`，否则在 C locale 下中文会写成 `\uXXXX`。

---

## 7. `theme()` 里 `size` 生效了，但图里的文字还是巨大

**原因**：`theme(element_text(size = 8))` 只管轴标签、图例、标题等 theme 元素；`geom_text()` / `annotate("text", size = 8)` 是另一套单位（mm）。

**做法**：两处都改。`geom_text` 用 `pt(8)`。

排查技巧：把 `base_size` 调到 20 看哪些文字跟着变——跟着变的是 theme 元素，不变的就是 geom 层级。

---

## 8. 中文显示为方框（tofu）

**现象**：图里中文位置出现空心方块。

**原因**：设备用的字体族里没有 CJK 字形。ragg 不会自动 fallback 到中文字体。

**做法**：注册字体并显式引用。

```r
register_cjk_font()                    # 内部用 systemfonts::register_font()
# 之后 family = "WB_CJK" 或字体族名 "SimSun"
```

先确认字体真实存在：`systemfonts::system_fonts()` 里查 family 字段，不要凭 Windows 文件名猜（`simsun.ttc` 的 family 是 `SimSun`）。

---

## 9. `ggsave()` 出来的图比预期小/大

**原因**：`ggsave()` 默认 `width = 7, height = 5, units = "in", dpi = 300`，且未指定 `device` 时按扩展名推断，不同 R 版本推断结果不同（可能走 `grDevices::tiff` 而非 ragg）。

**做法**：不用裸 `ggsave()`；若必须用，四个参数全写死。

```r
ggsave(
  filename = "fig01.tiff", plot = p,
  device = ragg::agg_tiff,
  width = 89, height = 59.333, units = "mm",
  dpi = 600, compression = "lzw", bg = "white"
)
```

`save_pub()` 已经封装好这些，优先用它。

---

## 10. 文件体积过大被投稿系统拒收

**排查顺序**：

1. `check_tiff_cli.R` 看 `compression` 是否为 5 —— 若为 1（none），说明 LZW 没生效；
2. 看 `dpi` 是否被误设成 1000+；
3. 看是否有 alpha 通道（`alpha: YES`），带 alpha 的图压缩率显著变差；
4. 若图中有大面积渐变/照片，LZW 压缩率天然低，考虑降到 300 dpi 或改用 JPEG（仅照片类，且需期刊允许）。

参考量级：190 × 250 mm @ 600 dpi、8 bit RGB、未压缩约 79.5 MB；LZW 后视内容为 8–30 MB。

---

## 11. `bootstrap.R` 找不到 `fig_spec.R`（定位到错误目录）

**现象**

```
Error: fig_spec.R not found next to bootstrap.R: .../some_other_dir/fig_spec.R
```

**原因**：`commandArgs()` 里的 `--file=` 指向的是 `Rscript` 的**入口脚本**，不是被 `source()` 的那个文件。用 `--file=` 推断 `bootstrap.R` 自身位置，得到的却是调用者所在目录。

**做法**：先遍历 `sys.frames()` 找 `$ofile`（`source()` 会写入被加载文件的真实路径），只有在 `bootstrap.R` 本身作为入口被 `Rscript` 直接执行时才回退到 `--file=`。`bootstrap.R` 已按此顺序实现。

```r
.this_dir <- function() {
  for (fr in sys.frames()) {
    if (!is.null(fr$ofile)) {
      return(dirname(normalizePath(fr$ofile, winslash = "/", mustWork = FALSE)))
    }
  }
  args <- commandArgs(trailingOnly = FALSE)
  fa <- sub("^--file=", "", args[grep("^--file=", args)])
  if (length(fa)) return(dirname(normalizePath(fa[1], winslash = "/", mustWork = FALSE)))
  getwd()
}
```

同类问题会出现在任何"库脚本自定位"的场景：不要相信 `--file=`，它在被 source 时永远指向别人。
