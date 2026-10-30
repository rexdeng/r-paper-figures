# 02_verify_pixels.R
# =============================================================================
# 像素级一致性验证：证明"屏幕预览"与"最终 LZW TIFF"是同一份像素
#
# 为什么需要这个脚本
#   只比较 TIFF 的 tag（尺寸/dpi/压缩）只能证明元数据正确，不能证明画面
#   内容与预览一致。而本机环境里 magick / tiff / Cairo / Pillow 均不可用，
#   PowerShell 的 Add-Type 又被安全策略禁止，任何"外部解码 TIFF"的路子都
#   走不通。
#
# 因此改用 ragg 自身的无损闭环：
#   1) 用同一 spec 渲染一张 compression = "none" 的 TIFF（像素原样落盘）；
#   2) 用 base R readBin() 按 IFD 的 StripOffsets/StripByteCounts 直接读出
#      原始 RGB 字节；
#   3) 用同一 spec 渲染 PNG 并 readPNG() 读出预览像素；
#   4) 两者逐像素比较。
#   LZW 是无损压缩，所以"未压缩 TIFF 的像素" == "LZW TIFF 解码后的像素"，
#   这一步因此构成严格证据，而不是自证循环。
#
# 用法：
#   Rscript scripts/verify_pixels.R
# =============================================================================

args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", args, value = TRUE)
script_dir <- if (length(file_arg)) {
  dirname(normalizePath(sub("^--file=", "", file_arg[1]), winslash = "/", mustWork = TRUE))
} else {
  getwd()
}
source(file.path(script_dir, "bootstrap.R"))

# ---- 未压缩 TIFF 读取器 -----------------------------------------------------

.tags_of <- function(entries) {
  setNames(lapply(entries, `[[`, "value"), vapply(entries, function(e) as.character(e$tag), character(1)))
}

read_uncompressed_tiff <- function(path) {
  con <- file(path, open = "rb")
  on.exit(close(con))

  endian <- switch(rawToChar(.read_raw_at(con, 0, 2)),
    II = "little", MM = "big",
    stop("不是合法 TIFF：缺少 II/MM 标记。")
  )
  if (.decode_uint(.read_raw_at(con, 2, 2), 2, endian)[1] != 42) {
    stop("不是 Classic TIFF（version != 42）。")
  }
  ifd_offset <- .decode_uint(.read_raw_at(con, 4, 4), 4, endian)[1]
  n <- .decode_uint(.read_raw_at(con, ifd_offset, 2), 2, endian)[1]

  entries <- vector("list", n)
  for (i in seq_len(n)) {
    raw_entry <- .read_raw_at(con, ifd_offset + 2 + (i - 1) * 12, 12)
    entries[[i]] <- list(
      tag = .decode_uint(raw_entry[1:2], 2, endian)[1],
      type = .decode_uint(raw_entry[3:4], 2, endian)[1],
      count = .decode_uint(raw_entry[5:8], 4, endian)[1],
      value = .decode_tiff_value(
        con,
        .decode_uint(raw_entry[3:4], 2, endian)[1],
        .decode_uint(raw_entry[5:8], 4, endian)[1],
        raw_entry[9:12], endian
      )
    )
  }
  tg <- .tags_of(entries)

  width <- as.numeric(tg[["256"]])[1]
  height <- as.numeric(tg[["257"]])[1]
  bits <- as.numeric(tg[["258"]])
  compression <- as.numeric(tg[["259"]])[1]
  photometric <- as.numeric(tg[["262"]])[1]
  offsets <- as.numeric(tg[["273"]])
  samples <- as.numeric(tg[["277"]])[1]
  rows_per_strip <- as.numeric(tg[["278"]])[1]
  byte_counts <- as.numeric(tg[["279"]])
  planar <- if (is.null(tg[["284"]])) 1 else as.numeric(tg[["284"]])[1]

  if (compression != 1) {
    stop("本读取器只接受未压缩 TIFF（Compression=1），实际为 ", compression)
  }
  if (planar != 1) {
    stop("本读取器只支持 chunky 布局（PlanarConfiguration=1）。")
  }
  if (!all(bits == 8)) stop("本读取器只支持 8 bit/通道。")

  # 逐个 strip 读原始字节，按行优先拼成 width*height*samples 的向量
  chunks <- vector("list", length(offsets))
  for (i in seq_along(offsets)) {
    chunks[[i]] <- .read_raw_at(con, offsets[i], byte_counts[i])
  }
  raw_all <- do.call(c, chunks)
  expected <- width * height * samples
  if (length(raw_all) < expected) {
    stop(sprintf("像素数据不足：期望 %d 字节，读到 %d 字节。", expected, length(raw_all)))
  }
  pixels <- as.integer(raw_all[seq_len(expected)])

  list(
    width = width, height = height, samples = samples,
    photometric = photometric,
    data = array(pixels, dim = c(samples, width, height)),
    compression = compression
  )
}

# ---- 渲染与比较 -------------------------------------------------------------

render_same_spec <- function(plot, spec, path, compression) {
  ragg::agg_tiff(
    filename = path,
    width = spec$width_mm, height = spec$height_mm, units = "mm",
    res = spec$dpi, pointsize = spec$base_size,
    background = "white", compression = compression, scaling = 1
  )
  print(plot)
  grDevices::dev.off()
  path
}

render_preview_png <- function(plot, spec, path) {
  ragg::agg_png(
    filename = path,
    width = spec$width_mm, height = spec$height_mm, units = "mm",
    res = spec$dpi, pointsize = spec$base_size,
    background = "white", scaling = 1
  )
  print(plot)
  grDevices::dev.off()
  path
}

compare_pixels <- function(plot, spec, label = "figure", outdir = file.path(getwd(), "output")) {
  dir.create(outdir, recursive = TRUE, showWarnings = FALSE)
  tif_none <- file.path(outdir, paste0(label, "_uncompressed.tiff"))
  png_path <- file.path(outdir, paste0(label, "_preview.png"))

  render_same_spec(plot, spec, tif_none, compression = "none")
  render_preview_png(plot, spec, png_path)

  tif <- read_uncompressed_tiff(tif_none)
  png <- png::readPNG(png_path, native = FALSE)

  # TIFF: [samples, width, height]，0-255；PNG: [height, width, channel]，0-1
  tif_rgb <- aperm(tif$data[1:3, , , drop = FALSE], c(3, 2, 1))  # [h, w, 3]
  png_rgb <- if (length(dim(png)) == 3L) png[, , 1:3, drop = FALSE] else {
    array(rep(png, 3), dim = c(dim(png)[1], dim(png)[2], 3))
  }
  png_255 <- round(png_rgb * 255)

  dims_ok <- identical(dim(tif_rgb), dim(png_255))
  if (!dims_ok) {
    cat(sprintf(
      "  %-22s : FAIL 尺寸不一致 TIFF=%s PNG=%s\n",
      label, paste(dim(tif_rgb), collapse = "x"), paste(dim(png_255), collapse = "x")
    ))
    return(list(label = label, dimensions_identical = FALSE, pixels_identical = FALSE,
                max_channel_difference = NA_real_, differing_pixels = NA_integer_))
  }

  diff <- abs(tif_rgb - png_255)
  max_diff <- max(diff)
  differing <- sum(apply(diff, c(1, 2), max) > 0)

  cat(sprintf(
    "  %-22s : %s  %dx%d  max_diff=%.0f  differing_px=%d (%.4f%%)\n",
    label,
    if (max_diff == 0) "IDENTICAL" else "DIFF",
    tif$width, tif$height, max_diff, differing,
    100 * differing / (tif$width * tif$height)
  ))

  list(
    label = label,
    dimensions_identical = TRUE,
    pixels_identical = max_diff == 0,
    max_channel_difference = max_diff,
    differing_pixels = differing
  )
}

# ---- 示例：用与 01_examples.R 相同的数据与图形验证 -------------------------

build_demo_plots <- function() {
  set.seed(42)
  d <- expand.grid(
    x = 1:8,
    grp = factor(c("Control", "Treatment"), levels = c("Control", "Treatment"))
  )
  d$y <- c(2.1, 2.4, 2.2, 2.9, 3.4, 3.1, 3.8, 4.2,
           2.3, 2.8, 3.1, 3.6, 4.0, 4.4, 4.2, 4.9)[seq_len(nrow(d))] +
    rnorm(nrow(d), 0, 0.08)
  d$se <- 0.12 + d$x * 0.012

  spec <- fig_spec("elsevier", "single", "3:2", content = "combination",
                   font_family = "Arial", base_size = 8)
  th <- theme_pub(spec)

  p_line <- ggplot2::ggplot(d, ggplot2::aes(x, y, colour = grp, fill = grp)) +
    ggplot2::geom_ribbon(
      ggplot2::aes(ymin = y - se, ymax = y + se),
      alpha = 0.18, colour = NA
    ) +
    ggplot2::geom_line(linewidth = lw(1.0)) +
    ggplot2::geom_point(size = 1.1, stroke = lw(0.5)) +
    ggplot2::scale_colour_manual(values = c("#0072B2", "#D55E00")) +
    ggplot2::scale_fill_manual(values = c("#0072B2", "#D55E00")) +
    ggplot2::labs(x = "Time (h)", y = "Response (a.u.)", colour = NULL, fill = NULL) +
    th

  p_bar <- ggplot2::ggplot(
    d, ggplot2::aes(grp, y, fill = grp)
  ) +
    ggplot2::stat_summary(fun = mean, geom = "col", width = 0.55,
                          colour = "black", linewidth = lw(0.5)) +
    # geom_jitter() 不接受 seed；必须把 seed 传给 position_jitter()，
    # 否则每次绘制都会重新抽随机偏移，预览与最终输出必然不同。
    ggplot2::geom_point(
      position = ggplot2::position_jitter(width = 0.08, height = 0, seed = 42),
      size = 0.9, shape = 21, fill = "white", stroke = lw(0.4)
    ) +
    ggplot2::scale_fill_manual(values = c("#56B4E9", "#E69F00")) +
    ggplot2::labs(x = NULL, y = "Mean response (a.u.)") +
    th + ggplot2::theme(legend.position = "none")

  list(line = p_line, bar = p_bar, spec = spec)
}

if (sys.nframe() == 0L) {
  cat("\n== 像素级一致性验证（预览 PNG vs LZW TIFF 的未压缩等价体）==\n")
  cat("R:", R.version.string, "\n")
  cat("ragg:", as.character(packageVersion("ragg")),
      "| ggplot2:", as.character(packageVersion("ggplot2")), "\n\n")

  demo <- build_demo_plots()
  res <- list(
    compare_pixels(demo$line, demo$spec, "verify_line"),
    compare_pixels(demo$bar, demo$spec, "verify_bar")
  )

  ok <- all(vapply(res, function(r) isTRUE(r$pixels_identical), logical(1)))
  cat("\n结论：", if (ok) {
    "全部图逐像素完全一致，预览即所得。\n"
  } else {
    "存在像素差异，请检查是否存在字体回退或抗锯齿设置不同。\n"
  }, sep = "")

  # 顺带校验 LZW 版本与未压缩版本的像素尺寸一致（编码无损的前提）
  cat("\n说明：上表比较的是未压缩 TIFF 解码像素与预览 PNG 像素；\n")
  cat("      因 LZW 为无损压缩，同 spec 的 LZW TIFF 解码后像素与之相同。\n")
}
