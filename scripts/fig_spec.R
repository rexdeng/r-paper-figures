# 00_fig_spec.R
# =============================================================================
# 科研论文位图输出规范模块
#
# 设计原则：预览与保存必须由同一个 fig_spec 对象驱动。不要依赖 RStudio
# Plots 面板的 Auto 尺寸，因为面板缩放会改变换行、图例布局以及视觉上的字号/
# 线宽比例；也不要依赖 ggsave() 的默认 dpi、设备或英寸尺寸。
#
# 单位陷阱（务必区分）：
#   * theme() / element_text(size = ...) 的单位是 pt（磅）；
#   * geom_text() / annotate("text") 的 size 单位是 mm，不是 pt；8 pt 应写
#     size = pt(8)，本文件的 pt() 会完成换算；
#   * ggplot2 >= 3.4 的 linewidth 单位是 mm；0.75 pt 应写
#     linewidth = lw(0.75)。
# 换算：1 inch = 25.4 mm = 72.27 TeX pt，约等于 72 PostScript pt；
#       1 PostScript pt = 0.352778 mm。
#
# 字体禁止项：不要启用 showtext。showtext 会接管文字栅格化，与 ragg 通过
# systemfonts/textshaping 解析字体的路径不同，容易造成预览与最终输出字形不一致。
# =============================================================================

.required_packages <- c("ggplot2", "ragg", "systemfonts")
.missing_packages <- .required_packages[
  !vapply(.required_packages, requireNamespace, logical(1), quietly = TRUE)
]
if (length(.missing_packages)) {
  stop("缺少必需 R 包：", paste(.missing_packages, collapse = ", "), call. = FALSE)
}

# ggplot2 内部对字体号使用 TeX point（72.27 pt/in）。在这里显式定义常数，
# 避免脚本 source 后依赖未导出的 ggplot2::.pt 对象。
.pt <- 72.27 / 25.4

#' 将字体磅值换算成 geom_text/annotate 所需的 mm 数值
pt <- function(x) {
  x <- as.numeric(x)
  if (any(!is.finite(x) | x < 0)) stop("pt 值必须是非负有限数。", call. = FALSE)
  x / .pt
}

#' 将线宽磅值换算成 ggplot2 linewidth 所需的 mm 数值
lw <- function(pt_val) {
  pt_val <- as.numeric(pt_val)
  if (any(!is.finite(pt_val) | pt_val < 0)) {
    stop("线宽 pt 值必须是非负有限数。", call. = FALSE)
  }
  pt_val * 0.352778
}

#' 打印科研绘图常用单位换算表
check_units <- function(print_table = TRUE) {
  out <- data.frame(
    context = c(
      "物理尺寸", "TeX 字体 point", "PostScript point",
      "theme()/element_text(size)", "geom_text()/annotate(size)",
      "ggplot2 linewidth"
    ),
    input_unit = c("inch", "pt", "pt", "pt", "mm", "mm"),
    conversion = c(
      "1 inch = 25.4 mm",
      "1 pt = 25.4 / 72.27 mm",
      "1 pt = 25.4 / 72 mm = 0.352778 mm",
      "直接填写磅值，例如 8",
      "8 pt 必须写 pt(8)，不能直接写 8",
      "0.75 pt 必须写 lw(0.75)"
    ),
    stringsAsFactors = FALSE
  )
  if (isTRUE(print_table)) print(out, row.names = FALSE)
  invisible(out)
}

#' 查询并显式注册可用中文字体
#'
#' @return 含 family、source_family、path、fallback 的列表。调用者应把
#'         返回的 family 直接传给 fig_spec(font_family = ...)。
register_cjk_font <- function(
    preferred = c("SimSun", "宋体", "SimHei", "黑体"),
    alias = "WB_CJK") {
  fonts <- systemfonts::system_fonts()
  family_text <- ifelse(is.na(fonts$family), "", fonts$family)
  name_text <- ifelse(is.na(fonts$name), "", fonts$name)

  hit <- integer(0)
  for (candidate in preferred) {
    idx <- which(
      tolower(family_text) == tolower(candidate) |
        tolower(name_text) == tolower(candidate)
    )
    if (!length(idx)) {
      idx <- which(
        grepl(tolower(candidate), tolower(family_text), fixed = TRUE) |
          grepl(tolower(candidate), tolower(name_text), fixed = TRUE)
      )
    }
    if (length(idx)) {
      # 优先 Regular/Normal，避免误把粗体文件注册为正文。
      style <- if ("style" %in% names(fonts)) fonts$style[idx] else ""
      regular <- idx[grepl("regular|normal|book|roman", style, ignore.case = TRUE)]
      hit <- if (length(regular)) regular[1] else idx[1]
      break
    }
  }

  if (!length(hit) || is.na(fonts$path[hit]) || !file.exists(fonts$path[hit])) {
    warning(
      "未找到 SimSun/SimHei 等中文字体；已显式回退到通用 serif。",
      call. = FALSE
    )
    return(list(
      family = "serif", source_family = NA_character_, path = NA_character_,
      fallback = TRUE
    ))
  }

  font_path <- normalizePath(fonts$path[hit], winslash = "/", mustWork = TRUE)
  registered <- tryCatch({
    systemfonts::register_font(name = alias, plain = font_path)
    TRUE
  }, error = function(e) {
    warning(
      "字体文件已找到但别名注册失败，将直接使用系统字体族 “",
      fonts$family[hit], "”：", conditionMessage(e),
      call. = FALSE
    )
    FALSE
  })

  list(
    family = if (registered) alias else fonts$family[hit],
    source_family = fonts$family[hit],
    font_name = fonts$name[hit],
    path = font_path,
    fallback = FALSE,
    registered = registered
  )
}

#' 创建唯一事实来源（single source of truth）的期刊图片规格
#'
#' @param journal 期刊/版式预设。
#' @param column single、onehalf 或 double。
#' @param aspect 3:2、4:3 或 custom（custom 时必须给 height_mm）。
#' @param content line/combination 默认 600 dpi；halftone/raster 默认 300 dpi。
fig_spec <- function(
    journal = c("nature", "science", "elsevier", "acs", "ieee", "cn_gb"),
    column = c("single", "onehalf", "double"),
    aspect = c("3:2", "4:3", "custom"),
    width_mm = NULL,
    height_mm = NULL,
    dpi = NULL,
    content = c("line", "combination", "halftone", "raster"),
    base_size = NULL,
    font_family = NULL,
    line_pt = 0.75,
    data_line_pt = 1.0,
    margin_mm = c(2.5, 2.5, 2.5, 2.5),
    tick_length_mm = 1.25) {
  journal <- match.arg(journal)
  column <- match.arg(column)
  aspect <- match.arg(aspect)
  content <- match.arg(content)

  # 宽度来源（投稿前务必以目标刊最新 Guide for Authors 复核）：
  #   Nature   89 / 120-136 / 183 mm，最大印刷高度 170 mm
  #   Science  55 mm（2.25 in）/ 120 mm（4.75 in）/ 全页 183 mm；AAAS 无 1.5 栏
  #            惯例，onehalf 取 90 mm 作为保守估算（不是官方数值）
  #   Elsevier 90 / 140 / 190 mm
  #   ACS      82.6 mm（3.25 in）/ 177.8 mm（7 in）；onehalf 为按比例估算值
  #   IEEE     88.9 mm（3.5 in）/ 181 mm（7.16 in）；onehalf 为估算值
  #   cn_gb    GB/T 7713 通用惯例 80 / 170 mm；onehalf 为估算值
  # 标注 [std] 的为官方公布值，标注 [est] 的为按版式推算、仅作起点。
  width_presets <- list(
    nature   = c(single = 89.0,  onehalf = 136.0, double = 183.0),  # [std]
    science  = c(single = 55.0,  onehalf = 90.0,  double = 120.0),  # [std]/[est]
    elsevier = c(single = 90.0,  onehalf = 140.0, double = 190.0),  # [std]
    acs      = c(single = 82.6,  onehalf = 130.2, double = 177.8),  # [std]/[est]
    ieee     = c(single = 88.9,  onehalf = 135.0, double = 181.0),  # [std]/[est]
    cn_gb    = c(single = 80.0,  onehalf = 125.0, double = 170.0)   # [est]
  )
  if (is.null(width_mm)) width_mm <- unname(width_presets[[journal]][column])
  width_mm <- as.numeric(width_mm)

  if (is.null(height_mm)) {
    if (aspect == "custom") {
      stop("aspect='custom' 时必须显式提供 height_mm。", call. = FALSE)
    }
    height_mm <- if (aspect == "3:2") width_mm * 2 / 3 else width_mm * 3 / 4
  }
  height_mm <- as.numeric(height_mm)

  if (is.null(dpi)) dpi <- if (content %in% c("line", "combination")) 600 else 300
  dpi <- as.integer(dpi)
  if (is.null(base_size)) base_size <- if (journal %in% c("nature", "science")) 7 else 8

  # 字体必须按目标刊要求给默认值：Nature / Science / Elsevier / ACS 的图内
  # 文字均要求 sans-serif（Arial 或 Helvetica），默认给 Times 会被 production
  # 替换或退回；IEEE 沿用 Times New Roman；中文刊正文用宋体。
  if (is.null(font_family)) {
    font_family <- switch(
      journal,
      nature   = "Arial",
      science  = "Arial",
      elsevier = "Arial",
      acs      = "Arial",
      ieee     = "Times New Roman",
      cn_gb    = "SimSun"
    )
  }

  if (
    length(width_mm) != 1L || length(height_mm) != 1L ||
      !is.finite(width_mm) || !is.finite(height_mm) ||
      width_mm <= 0 || height_mm <= 0
  ) {
    stop("width_mm 和 height_mm 必须是正的有限标量。", call. = FALSE)
  }
  if (length(dpi) != 1L || is.na(dpi) || dpi < 300L) {
    stop("出版位图 dpi 不得低于 300。", call. = FALSE)
  }
  if (line_pt < 0.5) warning("轴线/边框建议 >= 0.5 pt；当前设置偏细。", call. = FALSE)
  if (line_pt < 0.25 || data_line_pt < 0.25) {
    stop("任何线条均不得低于 0.25 pt。", call. = FALSE)
  }
  if (data_line_pt < 1.0) warning("数据线建议 >= 1.0 pt。", call. = FALSE)
  if (length(margin_mm) == 1L) margin_mm <- rep(margin_mm, 4L)
  if (length(margin_mm) != 4L || any(!is.finite(margin_mm) | margin_mm < 0)) {
    stop("margin_mm 必须是一个或四个非负 mm 数值（上、右、下、左）。", call. = FALSE)
  }

  structure(
    list(
      journal = journal,
      column = column,
      aspect = aspect,
      content = content,
      width_mm = width_mm,
      height_mm = height_mm,
      dpi = dpi,
      base_size = as.numeric(base_size),
      font_family = as.character(font_family),
      line_pt = as.numeric(line_pt),
      data_line_pt = as.numeric(data_line_pt),
      margin_mm = as.numeric(margin_mm),
      tick_length_mm = as.numeric(tick_length_mm),
      background = "white",
      # ragg 1.3.2 对 mm*dpi/25.4 的非整数像素采用向下取整，而不是 round()。
      # 将该实测行为写入 spec，预览 PNG 与 TIFF 因而共享完全相同的像素网格。
      expected_width_px = as.integer(floor(width_mm / 25.4 * dpi + 1e-9)),
      expected_height_px = as.integer(floor(height_mm / 25.4 * dpi + 1e-9))
    ),
    class = "fig_spec"
  )
}

print.fig_spec <- function(x, ...) {
  cat(
    sprintf(
      "<fig_spec> %s/%s: %.2f × %.2f mm, %d dpi, %.1f pt, font='%s'\n",
      x$journal, x$column, x$width_mm, x$height_mm, x$dpi,
      x$base_size, x$font_family
    )
  )
  invisible(x)
}

#' 统一的出版主题
#'
#' 默认让刻度朝外：向内刻度可能遮挡靠近坐标轴的数据点；向外刻度更适合
#' 数据密集的科研图。plot.margin 和 legend.key.size 均用 grid 单位显式指定。
theme_pub <- function(spec, tick_direction = c("out", "in")) {
  stopifnot(inherits(spec, "fig_spec"))
  tick_direction <- match.arg(tick_direction)
  tick_length <- if (tick_direction == "out") spec$tick_length_mm else -spec$tick_length_mm

  ggplot2::theme_classic(
    base_size = spec$base_size,
    base_family = spec$font_family
  ) +
    ggplot2::theme(
      text = ggplot2::element_text(
        family = spec$font_family,
        colour = "black",
        size = spec$base_size
      ),
      axis.title = ggplot2::element_text(size = spec$base_size),
      axis.text = ggplot2::element_text(size = spec$base_size, colour = "black"),
      axis.line = ggplot2::element_line(
        colour = "black", linewidth = lw(spec$line_pt), lineend = "square"
      ),
      axis.ticks = ggplot2::element_line(
        colour = "black", linewidth = lw(spec$line_pt), lineend = "square"
      ),
      axis.ticks.length = grid::unit(tick_length, "mm"),
      panel.grid = ggplot2::element_blank(),
      panel.border = ggplot2::element_blank(),
      legend.background = ggplot2::element_blank(),
      legend.key = ggplot2::element_blank(),
      legend.key.size = grid::unit(spec$base_size, "pt"),
      legend.title = ggplot2::element_text(size = spec$base_size),
      legend.text = ggplot2::element_text(size = spec$base_size),
      strip.background = ggplot2::element_blank(),
      strip.text = ggplot2::element_text(size = spec$base_size, face = "bold"),
      plot.title = ggplot2::element_text(size = spec$base_size + 1, face = "bold"),
      plot.tag = ggplot2::element_text(size = spec$base_size + 1, face = "bold"),
      plot.margin = ggplot2::margin(
        t = spec$margin_mm[1], r = spec$margin_mm[2],
        b = spec$margin_mm[3], l = spec$margin_mm[4], unit = "mm"
      )
    )
}

.open_ragg_device <- function(filename, spec, format) {
  if (format == "tiff") {
    # 硬性出版设置：8 bit/通道、LZW 无损、白底。白底避免 alpha 通道；
    # TIFF 是位图，不涉及字体嵌入。CMYK 不能由本函数可靠输出，须投稿前
    # 按期刊要求在 Photoshop/ImageMagick 等外部色彩管理软件中转换。
    ragg::agg_tiff(
      filename = filename,
      width = spec$width_mm,
      height = spec$height_mm,
      units = "mm",
      res = spec$dpi,
      pointsize = spec$base_size,
      background = "white",
      bitsize = 8,
      compression = "lzw",
      scaling = 1
    )
  } else if (format == "png") {
    ragg::agg_png(
      filename = filename,
      width = spec$width_mm,
      height = spec$height_mm,
      units = "mm",
      res = spec$dpi,
      pointsize = spec$base_size,
      background = "white",
      bitsize = 8,
      scaling = 1
    )
  } else {
    stop("仅支持 format='tiff' 或 'png'。", call. = FALSE)
  }
}

#' 按 fig_spec 保存 TIFF(LZW) 或 PNG
save_pub <- function(plot, filename, spec, format = c("tiff", "png")) {
  stopifnot(inherits(spec, "fig_spec"))
  format <- match.arg(format)
  parent <- dirname(filename)
  if (!dir.exists(parent)) dir.create(parent, recursive = TRUE, showWarnings = FALSE)
  filename <- normalizePath(filename, winslash = "/", mustWork = FALSE)

  .open_ragg_device(filename, spec, format)
  device_id <- grDevices::dev.cur()
  closed <- FALSE
  on.exit({
    open_devices <- grDevices::dev.list()
    if (!closed && !is.null(open_devices) && device_id %in% open_devices) {
      grDevices::dev.off(device_id)
    }
  }, add = TRUE)
  print(plot)
  grDevices::dev.off(device_id)
  closed <- TRUE

  if (!file.exists(filename) || file.info(filename)$size <= 0) {
    stop("输出文件未成功生成：", filename, call. = FALSE)
  }
  invisible(filename)
}

.render_preview_png <- function(plot, spec, filename) {
  save_pub(plot, filename, spec, format = "png")
  filename
}

#' 在相同物理尺寸与 dpi 下预览
#'
#' ragg 先按最终规格渲染临时 PNG，随后 png::readPNG() 读取，并将 raster 放进
#' width/height 都以 mm 指定的 viewport；因此字号、线宽和布局与保存设备共用
#' 同一个 spec。若屏幕窗口小于成图物理尺寸，画面可能被裁切，但不会被偷偷缩放。
preview_pub <- function(plot, spec, display = interactive(), filename = NULL) {
  stopifnot(inherits(spec, "fig_spec"))
  if (is.null(filename)) filename <- tempfile(fileext = ".png")
  .render_preview_png(plot, spec, filename)

  if (!requireNamespace("png", quietly = TRUE)) {
    warning(
      "未安装 png 包，不能把预渲染 PNG 读回 grid；退化为固定尺寸设备预览。",
      call. = FALSE
    )
    if (isTRUE(display)) {
      grDevices::dev.new(
        width = spec$width_mm / 25.4,
        height = spec$height_mm / 25.4,
        noRStudioGD = TRUE
      )
      actual <- grDevices::dev.size("in") * 25.4
      if (any(abs(actual - c(spec$width_mm, spec$height_mm)) > 0.5)) {
        warning("固定尺寸窗口与 spec 相差超过 0.5 mm。", call. = FALSE)
      }
      print(plot)
    }
    return(invisible(list(
      path = filename,
      width_px = spec$expected_width_px,
      height_px = spec$expected_height_px,
      displayed = isTRUE(display),
      mode = "fixed-device-fallback"
    )))
  }

  image <- png::readPNG(filename, native = FALSE)
  dims <- dim(image)[1:2]
  if (isTRUE(display)) {
    grid::grid.newpage()
    grid::pushViewport(grid::viewport(
      width = grid::unit(spec$width_mm, "mm"),
      height = grid::unit(spec$height_mm, "mm"),
      clip = "on"
    ))
    grid::grid.raster(
      image,
      width = grid::unit(1, "npc"), height = grid::unit(1, "npc"),
      interpolate = FALSE
    )
    grid::popViewport()
  }
  invisible(list(
    path = normalizePath(filename, winslash = "/", mustWork = TRUE),
    width_px = dims[2],
    height_px = dims[1],
    displayed = isTRUE(display),
    mode = "ragg-png-grid-raster"
  ))
}

# ---- 不依赖 tiff/magick/Cairo 的 TIFF IFD 解析器 ---------------------------
.decode_uint <- function(raw_value, size, endian) {
  con <- rawConnection(raw_value, open = "rb")
  on.exit(close(con))
  # base R 4.3 的 readBin(signed = FALSE) 仅对 1/2-byte integer 有效；
  # 4-byte TIFF LONG 先按有符号整数读取，再提升到 double 并补回 2^32，
  # 以避免 warning，同时正确覆盖 Classic TIFF 的无符号偏移。
  if (size %in% c(1, 2)) {
    return(readBin(
      con, what = "integer", n = length(raw_value) / size,
      size = size, signed = FALSE, endian = endian
    ))
  }
  out <- as.numeric(readBin(
    con, what = "integer", n = length(raw_value) / size,
    size = size, signed = TRUE, endian = endian
  ))
  out[out < 0] <- out[out < 0] + 2^32
  out
}

.read_raw_at <- function(con, offset, n) {
  seek(con, where = offset, origin = "start")
  ans <- readBin(con, what = "raw", n = n)
  if (length(ans) != n) stop("TIFF 文件意外结束或 IFD 偏移无效。", call. = FALSE)
  ans
}

.decode_tiff_value <- function(con, type, count, value_field, endian) {
  type_size <- c(`1` = 1, `2` = 1, `3` = 2, `4` = 4, `5` = 8,
                 `6` = 1, `7` = 1, `8` = 2, `9` = 4, `10` = 8,
                 `11` = 4, `12` = 8)
  if (!as.character(type) %in% names(type_size)) {
    return(NA)
  }
  n_bytes <- as.numeric(type_size[as.character(type)]) * as.numeric(count)
  if (n_bytes <= 4) {
    payload <- value_field[seq_len(n_bytes)]
  } else {
    value_offset <- .decode_uint(value_field, 4, endian)[1]
    payload <- .read_raw_at(con, value_offset, n_bytes)
  }

  if (type %in% c(1, 6, 7)) return(as.integer(payload))
  if (type == 2) return(sub("\\x00+$", "", rawToChar(payload)))
  if (type %in% c(3, 8)) return(.decode_uint(payload, 2, endian))
  if (type %in% c(4, 9)) return(.decode_uint(payload, 4, endian))
  if (type %in% c(5, 10)) {
    vals <- .decode_uint(payload, 4, endian)
    numer <- vals[seq(1, length(vals), by = 2)]
    denom <- vals[seq(2, length(vals), by = 2)]
    return(numer / denom)
  }
  NA
}

#' 用 base R readBin() 校验 TIFF 文件头和首个 IFD
#'
#' @param path TIFF 路径。
#' @param spec 可选但强烈建议传入。传入后验证 tag 推导的物理尺寸与 spec
#'             的误差小于 tolerance_mm，并验证像素数与 mm*dpi 换算一致。
check_tiff <- function(path, spec = NULL, tolerance_mm = 0.5, verbose = TRUE) {
  if (!file.exists(path)) stop("TIFF 文件不存在：", path, call. = FALSE)
  if (!is.null(spec) && !inherits(spec, "fig_spec")) {
    stop("spec 必须是 fig_spec() 的返回值。", call. = FALSE)
  }

  con <- file(path, open = "rb")
  on.exit(close(con))
  byte_order_raw <- .read_raw_at(con, 0, 2)
  byte_order <- rawToChar(byte_order_raw)
  endian <- switch(byte_order, II = "little", MM = "big",
                   stop("不是合法 TIFF 字节序标记（II/MM）。", call. = FALSE))
  version <- .decode_uint(.read_raw_at(con, 2, 2), 2, endian)[1]
  ifd_offset <- .decode_uint(.read_raw_at(con, 4, 4), 4, endian)[1]
  entry_count <- .decode_uint(.read_raw_at(con, ifd_offset, 2), 2, endian)[1]

  entries <- vector("list", entry_count)
  for (i in seq_len(entry_count)) {
    entry_raw <- .read_raw_at(con, ifd_offset + 2 + (i - 1) * 12, 12)
    tag <- .decode_uint(entry_raw[1:2], 2, endian)[1]
    type <- .decode_uint(entry_raw[3:4], 2, endian)[1]
    count <- .decode_uint(entry_raw[5:8], 4, endian)[1]
    value <- .decode_tiff_value(con, type, count, entry_raw[9:12], endian)
    entries[[i]] <- list(tag = tag, type = type, count = count, value = value)
  }
  names(entries) <- vapply(entries, function(x) as.character(x$tag), character(1))
  tag_value <- function(tag, default = NA) {
    item <- entries[[as.character(tag)]]
    if (is.null(item)) default else item$value
  }

  width_px <- as.numeric(tag_value(256))[1]
  height_px <- as.numeric(tag_value(257))[1]
  bits <- as.numeric(tag_value(258))
  compression <- as.numeric(tag_value(259))[1]
  photometric <- as.numeric(tag_value(262))[1]
  samples <- as.numeric(tag_value(277))[1]
  x_resolution_raw <- as.numeric(tag_value(282))[1]
  y_resolution_raw <- as.numeric(tag_value(283))[1]
  resolution_unit <- as.numeric(tag_value(296))[1]

  if (resolution_unit == 2) {
    x_dpi <- x_resolution_raw
    y_dpi <- y_resolution_raw
    physical_width_mm <- width_px / x_dpi * 25.4
    physical_height_mm <- height_px / y_dpi * 25.4
    resolution_unit_label <- "inch"
  } else if (resolution_unit == 3) {
    # TIFF tag 3 表示 dots/cm，不是 dpi；必须乘 2.54 才得到 dots/inch。
    x_dpi <- x_resolution_raw * 2.54
    y_dpi <- y_resolution_raw * 2.54
    physical_width_mm <- width_px / x_resolution_raw * 10
    physical_height_mm <- height_px / y_resolution_raw * 10
    resolution_unit_label <- "centimeter"
  } else {
    x_dpi <- y_dpi <- physical_width_mm <- physical_height_mm <- NA_real_
    resolution_unit_label <- "none/unknown"
  }

  width_error_mm <- height_error_mm <- NA_real_
  expected_width_px <- expected_height_px <- NA_integer_
  if (!is.null(spec)) {
    width_error_mm <- physical_width_mm - spec$width_mm
    height_error_mm <- physical_height_mm - spec$height_mm
    expected_width_px <- as.integer(floor(spec$width_mm / 25.4 * spec$dpi + 1e-9))
    expected_height_px <- as.integer(floor(spec$height_mm / 25.4 * spec$dpi + 1e-9))
  }

  checks <- c(
    byte_order = byte_order %in% c("II", "MM"),
    tiff_version_42 = identical(as.numeric(version), 42),
    lzw_compression = identical(as.numeric(compression), 5),
    eight_bit_channels = length(bits) >= 3 && all(bits == 8),
    rgb_photometric = identical(as.numeric(photometric), 2),
    rgb_samples = identical(as.numeric(samples), 3),
    valid_resolution = is.finite(x_dpi) && is.finite(y_dpi) && x_dpi > 0 && y_dpi > 0
  )
  if (!is.null(spec)) {
    checks <- c(
      checks,
      width_mm_matches_spec = is.finite(width_error_mm) && abs(width_error_mm) < tolerance_mm,
      height_mm_matches_spec = is.finite(height_error_mm) && abs(height_error_mm) < tolerance_mm,
      width_px_matches_spec = identical(as.integer(width_px), expected_width_px),
      height_px_matches_spec = identical(as.integer(height_px), expected_height_px)
    )
  }

  result <- structure(
    list(
      path = normalizePath(path, winslash = "/", mustWork = TRUE),
      byte_order = byte_order,
      endian = endian,
      version = version,
      ifd_offset = ifd_offset,
      width_px = width_px,
      height_px = height_px,
      bits_per_sample = bits,
      compression = compression,
      compression_label = if (compression == 5) "LZW" else paste0("tag-", compression),
      photometric = photometric,
      photometric_label = if (photometric == 2) "RGB" else paste0("tag-", photometric),
      samples_per_pixel = samples,
      x_resolution_raw = x_resolution_raw,
      y_resolution_raw = y_resolution_raw,
      resolution_unit = resolution_unit,
      resolution_unit_label = resolution_unit_label,
      x_dpi = x_dpi,
      y_dpi = y_dpi,
      physical_width_mm = physical_width_mm,
      physical_height_mm = physical_height_mm,
      width_error_mm = width_error_mm,
      height_error_mm = height_error_mm,
      expected_width_px = expected_width_px,
      expected_height_px = expected_height_px,
      file_size_kb = unname(file.info(path)$size / 1024),
      checks = checks,
      passed = all(checks)
    ),
    class = "tiff_check"
  )

  if (isTRUE(verbose)) print(result)
  if (!result$passed) {
    failed <- names(checks)[!checks]
    stop("TIFF 校验失败：", paste(failed, collapse = ", "), call. = FALSE)
  }
  invisible(result)
}

print.tiff_check <- function(x, ...) {
  # 逐行输出而不是 print(data.frame)：Path 是很长的绝对路径，data.frame 的
  # 自动列宽会被它撑爆，导致终端里 field 与 value 两列错位、完全不可读。
  row <- function(label, value) {
    cat(sprintf("  %-17s: %s\n", label, value))
  }
  cat("\n<TIFF check> ", basename(x$path), "\n", sep = "")
  row("file", x$path)
  row("byte order", paste0(x$byte_order, " / ", x$endian))
  row("tiff version", as.character(x$version))
  row("pixels", sprintf("%d x %d", x$width_px, x$height_px))
  row("bits/sample", paste(x$bits_per_sample, collapse = ","))
  row("compression", sprintf("%d (%s)", x$compression, x$compression_label))
  row("photometric", sprintf("%d (%s)", x$photometric, x$photometric_label))
  row("samples/pixel", as.character(x$samples_per_pixel))
  row("resolution", sprintf(
    "%.4f x %.4f (%s)",
    x$x_resolution_raw, x$y_resolution_raw, x$resolution_unit_label
  ))
  row("effective dpi", sprintf("%.2f x %.2f", x$x_dpi, x$y_dpi))
  row("physical size", sprintf("%.3f x %.3f mm", x$physical_width_mm, x$physical_height_mm))
  if (!is.null(x$expected_width_px) && !is.na(x$expected_width_px)) {
    row("expected px", sprintf("%d x %d", x$expected_width_px, x$expected_height_px))
    row("size error", sprintf("%+.3f / %+.3f mm", x$width_error_mm, x$height_error_mm))
  }
  row("file size", sprintf("%.1f KB", x$file_size_kb))
  row("all checks", if (x$passed) "PASS" else {
    paste0("FAIL -> ", paste(names(x$checks)[!x$checks], collapse = ", "))
  })
  cat("\n")
  invisible(x)
}

# ---- 像素级读取：base R 解析 IFD + 自研 LZW 解码 -------------------------
# 为什么要自己写解码器：本机没有 magick / tiff / Cairo / Pillow，powershell 的
# Add-Type 也被安全策略禁止，外部解码路径全部不可用。若退化为"再渲染一张 PNG
# 和预览 PNG 比"，那是自证循环，不能证明最终 LZW TIFF 与预览一致。
# 因此这里用 readBin() 读 StripOffsets/StripByteCounts，自己实现 TIFF LZW
# 解码，把最终交付文件的真实像素解出来；再用同 spec 的未压缩 TIFF 作为解码器
# 的真值参照（LZW 是无损压缩，解码结果必须与未压缩逐字节相同）。

.read_tiff_ifd <- function(path) {
  con <- file(path, open = "rb")
  on.exit(close(con))
  byte_order <- rawToChar(.read_raw_at(con, 0, 2))
  endian <- switch(
    byte_order, II = "little", MM = "big",
    stop("不是合法 TIFF 字节序标记（II/MM）。", call. = FALSE)
  )
  version <- .decode_uint(.read_raw_at(con, 2, 2), 2, endian)[1]
  ifd_offset <- .decode_uint(.read_raw_at(con, 4, 4), 4, endian)[1]
  entry_count <- .decode_uint(.read_raw_at(con, ifd_offset, 2), 2, endian)[1]

  entries <- vector("list", entry_count)
  for (i in seq_len(entry_count)) {
    entry_raw <- .read_raw_at(con, ifd_offset + 2 + (i - 1) * 12, 12)
    entries[[i]] <- list(
      tag = .decode_uint(entry_raw[1:2], 2, endian)[1],
      type = .decode_uint(entry_raw[3:4], 2, endian)[1],
      count = .decode_uint(entry_raw[5:8], 4, endian)[1],
      value = .decode_tiff_value(
        con, .decode_uint(entry_raw[3:4], 2, endian)[1],
        .decode_uint(entry_raw[5:8], 4, endian)[1], entry_raw[9:12], endian
      )
    )
  }
  names(entries) <- vapply(entries, function(x) as.character(x$tag), character(1))
  list(
    path = path, byte_order = byte_order, endian = endian, version = version,
    ifd_offset = ifd_offset, entries = entries
  )
}

.tiff_tag <- function(ifd, tag, default = NA) {
  item <- ifd$entries[[as.character(tag)]]
  if (is.null(item)) default else item$value
}

#' TIFF LZW 解码（纯 base R）
#'
#' TIFF 使用的是“改进版 LZW”：9–12 bit 变长码、MSB 优先打包、ClearCode=256、
#' EOI=257。历史上部分编码器在码宽增长上“提前一位”（early change），因此
#' 提供 early_change 开关，由 read_tiff_pixels() 用未压缩真值自动判定。
.lzw_decompress <- function(raw_bytes, expected, early_change = FALSE) {
  if (!length(raw_bytes)) stop("空 strip，无法解码。", call. = FALSE)
  # rawToBits 按字节给出 LSB→MSB，TIFF LZW 需要 MSB 优先，因此倒序排列。
  bits_mat <- matrix(as.integer(rawToBits(raw_bytes)), nrow = 8L)
  bitv <- as.vector(bits_mat[8:1, , drop = FALSE])
  n_bits <- length(bitv)
  pow <- 2^(0:12)

  out <- integer(expected)
  o <- 1L
  prefix <- rep(-1L, 4096L)        # 词条 = string(prefix) + lastch
  lastch <- rep(0L, 4096L)
  lastch[1:256] <- 0:255           # 0..255 为字面量
  stack <- integer(4096L)
  code_size <- 9L
  max_code <- 511L
  next_free <- 258L
  old <- -1L
  pos <- 1L

  while (pos + code_size - 1L <= n_bits) {
    code <- sum(bitv[pos:(pos + code_size - 1L)] * pow[code_size:1L])
    pos <- pos + code_size

    if (code == 257L) break                       # EOI
    if (code == 256L) {                           # ClearCode：重置字典
      code_size <- 9L; max_code <- 511L; next_free <- 258L; old <- -1L
      next
    }
    if (old < 0L) {                               # 流起始：必须是字面量
      if (code > 255L) stop("LZW 流非法：首个非清除码不是字面量。", call. = FALSE)
      if (o > expected) stop("LZW 输出超出预期长度。", call. = FALSE)
      out[o] <- code
      o <- o + 1L
      old <- code
      next
    }
    if (code > next_free) stop("LZW 流非法：出现无法解析的码。", call. = FALSE)

    # 沿 prefix 链回溯词条，栈内为逆序字符
    sp <- 0L
    c0 <- if (code == next_free) old else code
    repeat {
      sp <- sp + 1L
      stack[sp] <- lastch[c0 + 1L]
      p <- prefix[c0 + 1L]
      if (p < 0L) break
      c0 <- p
    }
    first <- stack[sp]
    len <- sp
    # 边界判断要区分两种情况：普通词条写 len 个字节（末位 o+len-1），
    # code == next_free 的特殊情况还要多写 1 个首字节（末位 o+len）。
    if (o + len - 1L > expected) stop("LZW 输出超出预期长度。", call. = FALSE)
    out[o:(o + len - 1L)] <- stack[len:1L]
    if (code == next_free) {                      # 特殊情况：词条尚未入表
      if (o + len > expected) stop("LZW 输出超出预期长度。", call. = FALSE)
      out[o + len] <- first
      o <- o + len + 1L
    } else {
      o <- o + len
    }

    if (next_free < 4096L) {
      prefix[next_free + 1L] <- old
      lastch[next_free + 1L] <- first
      next_free <- next_free + 1L
      grow <- if (isTRUE(early_change)) next_free >= max_code else next_free > max_code
      if (grow && code_size < 12L) {
        code_size <- code_size + 1L
        max_code <- 2^code_size - 1L
      }
    }
    old <- code
  }

  if (o - 1L != expected) {
    stop(
      sprintf("LZW 解码长度 %d 与预期 %d 不一致（码宽变体可能不匹配）。",
              o - 1L, expected),
      call. = FALSE
    )
  }
  out
}

#' 读取 TIFF 的 RGB 像素矩阵（integer 0-255，维度 高×宽×通道）
#'
#' 支持 compression=1（未压缩）与 compression=5（LZW，自研解码）。
#' 结果带 early_change 属性，供调用者如实记录所用码宽变体。
read_tiff_pixels <- function(path, early_change = NA) {
  ifd <- .read_tiff_ifd(path)
  width <- as.numeric(.tiff_tag(ifd, 256))[1]
  height <- as.numeric(.tiff_tag(ifd, 257))[1]
  bits <- as.numeric(.tiff_tag(ifd, 258))
  compression <- as.numeric(.tiff_tag(ifd, 259))[1]
  spp <- as.numeric(.tiff_tag(ifd, 277))[1]
  rps <- as.numeric(.tiff_tag(ifd, 278))[1]
  offsets <- as.numeric(.tiff_tag(ifd, 273))
  counts <- as.numeric(.tiff_tag(ifd, 279))
  planar <- as.numeric(.tiff_tag(ifd, 284, 1))[1]
  predictor <- as.numeric(.tiff_tag(ifd, 317, 1))[1]

  if (is.na(width) || is.na(height) || is.na(spp)) {
    stop("TIFF 缺少 ImageWidth/ImageLength/SamplesPerPixel。", call. = FALSE)
  }
  if (!all(bits[seq_len(spp)] == 8)) stop("仅支持 8 bit/通道的 TIFF。", call. = FALSE)
  if (planar != 1) stop("仅支持 PlanarConfiguration=1（chunky）。", call. = FALSE)
  if (is.na(rps) || rps > height) rps <- height
  if (length(offsets) != length(counts)) {
    stop("StripOffsets 与 StripByteCounts 数量不一致。", call. = FALSE)
  }

  # 实测：ragg 1.3.2（libtiff 系）采用 early change 码宽约定，故优先尝试它，
  # 失败再退到标准约定，由调用方用未压缩真值判定，绝不猜。
  variants <- if (identical(early_change, NA)) c(TRUE, FALSE) else early_change
  used_variant <- NA
  strips <- vector("list", length(offsets))
  con <- file(path, open = "rb")
  on.exit(close(con))
  for (s in seq_along(offsets)) {
    rows <- min(rps, height - (s - 1) * rps)
    expected <- rows * width * spp
    raw_strip <- .read_raw_at(con, offsets[s], counts[s])

    if (compression == 1) {
      if (length(raw_strip) != expected) {
        stop(sprintf("未压缩 strip %d 长度 %d != 预期 %d。", s, length(raw_strip), expected),
             call. = FALSE)
      }
      data <- raw_strip
    } else if (compression == 5) {
      data <- NULL
      for (v in variants) {
        res <- tryCatch(.lzw_decompress(raw_strip, expected, early_change = v),
                        error = function(e) e)
        if (!inherits(res, "error") && length(res) == expected) {
          data <- res
          used_variant <- v
          break
        }
      }
      if (is.null(data)) {
        stop(sprintf("LZW strip %d 解码失败（已尝试 early_change=FALSE/TRUE）。", s),
             call. = FALSE)
      }
    } else {
      stop(sprintf("不支持的 Compression tag：%s。", compression), call. = FALSE)
    }

    arr <- array(as.integer(data), dim = c(spp, width, rows))
    strips[[s]] <- aperm(arr, c(3, 2, 1))   # (高, 宽, 通道)
  }

  image <- if (length(strips) == 1L) strips[[1]] else do.call(rbind, strips)
  if (predictor == 2) {                     # 水平差分（ragg 实测写 1，仍保留兜底）
    for (ch in seq_len(spp)) {
      image[, , ch] <- t(apply(image[, , ch, drop = FALSE][, , 1], 1, function(row) {
        as.integer(cumsum(as.numeric(row)) %% 256)
      }))
    }
  }
  attr(image, "early_change") <- used_variant
  attr(image, "compression") <- compression
  image
}

# ---- 预览与最终 TIFF 的像素级闭环比对 -------------------------------------
.rgb_only <- function(x) {
  if (length(dim(x)) == 3L && dim(x)[3] >= 3L) x[, , 1:3, drop = FALSE] else x
}

#' 同 spec 输出未压缩 TIFF，作为 LZW 解码结果的真值参照
.save_tiff_uncompressed <- function(plot, filename, spec) {
  parent <- dirname(filename)
  if (!dir.exists(parent)) dir.create(parent, recursive = TRUE, showWarnings = FALSE)
  filename <- normalizePath(filename, winslash = "/", mustWork = FALSE)
  ragg::agg_tiff(
    filename = filename,
    width = spec$width_mm, height = spec$height_mm, units = "mm",
    res = spec$dpi, pointsize = spec$base_size, background = "white",
    bitsize = 8, compression = "none", scaling = 1
  )
  device_id <- grDevices::dev.cur()
  closed <- FALSE
  on.exit({
    open_devices <- grDevices::dev.list()
    if (!closed && !is.null(open_devices) && device_id %in% open_devices) {
      grDevices::dev.off(device_id)
    }
  }, add = TRUE)
  print(plot)
  grDevices::dev.off(device_id)
  closed <- TRUE
  filename
}

#' 证明“预览 == 最终 LZW TIFF”
#'
#' 证据链（全程不依赖任何第三方解码器）：
#'   1. read_tiff_pixels() 解析交付文件的 IFD 与 strip，自研 LZW 解码得到真实像素；
#'   2. 同 spec 输出未压缩 TIFF，其像素由 strip 直接读出，作为解码器真值；
#'      两者相同 ⇔ LZW 解码正确且压缩无损；
#'   3. 预览 PNG（同 spec，ragg PNG）与解码出的 LZW 像素逐通道比对。
#' 若 png 包缺失，会如实返回 NA，绝不再用“重渲染 PNG 对比”冒充 TIFF 解码。
preview_pair <- function(
    plot, tiff_path, spec,
    preview_file = tempfile(fileext = ".png"),
    uncompressed_file = tempfile(fileext = ".tiff"),
    display = interactive()) {
  stopifnot(inherits(spec, "fig_spec"))
  if (!file.exists(tiff_path)) save_pub(plot, tiff_path, spec, format = "tiff")
  tiff_info <- check_tiff(tiff_path, spec = spec, verbose = FALSE)
  preview_info <- preview_pub(plot, spec, display = FALSE, filename = preview_file)

  decoded <- read_tiff_pixels(tiff_path)                    # 交付文件的真实像素
  .save_tiff_uncompressed(plot, uncompressed_file, spec)
  ground_truth <- read_tiff_pixels(uncompressed_file)       # 未压缩真值

  dims_ok <- identical(dim(decoded), dim(ground_truth)) &&
    dim(decoded)[2] == tiff_info$width_px &&
    dim(decoded)[1] == tiff_info$height_px
  lzw_max_diff <- if (dims_ok) max(abs(decoded - ground_truth)) else Inf

  preview_dim_ok <- identical(
    as.integer(c(dim(decoded)[1], dim(decoded)[2])),
    as.integer(c(preview_info$height_px, preview_info$width_px))
  )
  preview_max_diff <- NA_real_
  preview_pixels_identical <- NA
  comparison_mode <- sprintf(
    "decoded final LZW TIFF via base-R IFD+strip+LZW decoder (early_change=%s); uncompressed TIFF as decoder ground truth",
    attr(decoded, "early_change")
  )

  if (requireNamespace("png", quietly = TRUE)) {
    png_array <- .rgb_only(png::readPNG(preview_file, native = FALSE))
    # PNG 为 0-1 double，TIFF 为 0-255 integer，先统一量纲再比较。
    png_pixels <- array(as.integer(round(png_array * 255)), dim = dim(png_array))
    preview_dim_ok <- preview_dim_ok && identical(dim(png_pixels), dim(decoded))
    if (preview_dim_ok) {
      preview_max_diff <- max(abs(png_pixels - decoded))
      preview_pixels_identical <- identical(png_pixels, decoded) ||
        isTRUE(preview_max_diff == 0)
    } else {
      preview_max_diff <- Inf
      preview_pixels_identical <- FALSE
    }
  } else {
    comparison_mode <- paste0(
      comparison_mode, "; png package unavailable -> preview pixel comparison = NA"
    )
  }

  if (isTRUE(display)) {
    grid::grid.newpage()
    grid::pushViewport(grid::viewport(layout = grid::grid.layout(1, 2)))
    grid::pushViewport(grid::viewport(layout.pos.row = 1, layout.pos.col = 1))
    grid::grid.raster(png::readPNG(preview_file, native = FALSE), interpolate = FALSE)
    grid::grid.text("Preview render", y = grid::unit(1, "npc") - grid::unit(2, "mm"),
                    just = "top", gp = grid::gpar(fontsize = 8))
    grid::popViewport()
    grid::pushViewport(grid::viewport(layout.pos.row = 1, layout.pos.col = 2))
    grid::grid.raster(decoded / 255, interpolate = FALSE)
    grid::grid.text("Decoded final LZW TIFF", y = grid::unit(1, "npc") - grid::unit(2, "mm"),
                    just = "top", gp = grid::gpar(fontsize = 8))
    grid::popViewport(2)
  }

  result <- list(
    tiff_path = normalizePath(tiff_path, winslash = "/", mustWork = TRUE),
    preview_file = normalizePath(preview_file, winslash = "/", mustWork = TRUE),
    uncompressed_file = normalizePath(uncompressed_file, winslash = "/", mustWork = TRUE),
    width_px = dim(decoded)[2],
    height_px = dim(decoded)[1],
    dimensions_identical = dims_ok && preview_dim_ok,
    pixels_identical = preview_pixels_identical,
    max_channel_difference = preview_max_diff,
    lzw_vs_uncompressed_identical = isTRUE(lzw_max_diff == 0),
    lzw_vs_uncompressed_max_diff = lzw_max_diff,
    early_change = attr(decoded, "early_change"),
    comparison_mode = comparison_mode
  )
  message(
    "preview_pair: decoded-LZW vs uncompressed max_diff=", lzw_max_diff,
    "; preview-PNG vs decoded-TIFF max_diff=", preview_max_diff,
    "; identical=", result$pixels_identical,
    "\n  mode: ", result$comparison_mode, sep = ""
  )
  invisible(result)
}

if (sys.nframe() == 0L) {
  cat("00_fig_spec.R 自检：核心函数加载成功。\n")
  check_units()
  demo_spec <- fig_spec("nature", "single", "3:2")
  print(demo_spec)
  cat("必要包版本：\n")
  for (pkg in .required_packages) {
    cat(sprintf("  %-12s %s\n", pkg, as.character(utils::packageVersion(pkg))))
  }
  cat("注意：showtext 未启用；字体解析统一交由 systemfonts + ragg。\n")
}
