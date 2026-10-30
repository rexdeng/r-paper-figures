#!/usr/bin/env Rscript
# =============================================================================
# check_tiff_cli.R —— 独立的期刊 TIFF 合规校验器（仅依赖 base R）
#
# 为什么单独做一个 CLI：
#   1) fig_spec.R 依赖 ggplot2/ragg，只为校验一个 TIFF 就加载整条绘图栈不划算；
#      某些受限环境（如 Windows 沙箱）加载 cli/ggplot2 后进程退出会异常。
#   2) 校验必须基于文件内 IFD 标签，而不是文件名或"生成时我记得设了 600dpi"。
#      本脚本直接解析 TIFF header + 首个 IFD，反算物理尺寸。
#
# 只做校验，不做转换；只读文件，不修改文件。
#
# 用法：
#   Rscript check_tiff_cli.R fig.tiff
#   Rscript check_tiff_cli.R fig.tiff --width 89 --height 59.3 --dpi 600
#   Rscript check_tiff_cli.R output/*.tiff --json
#
# 参数：
#   --width  <mm>    期望物理宽度，给出则校验反算尺寸误差
#   --height <mm>    期望物理高度
#   --dpi    <num>   期望有效分辨率，给出则校验像素数 = floor(mm/25.4*dpi)
#   --tol    <mm>    物理尺寸容差，默认 0.5 mm
#   --allow-compression <n>  允许的 Compression tag，默认 5(LZW)；
#                    传 1 表示允许未压缩（调试用），可逗号分隔如 5,8
#   --json           以 JSON 输出，便于程序消费
#
# 退出码：0 全部通过；1 有文件不合规；2 参数或读取错误。
#
# 注意：校验项是"期刊合规的必要条件"，通过≠一定被接收（还涉及内容、色彩空间等）。
# =============================================================================

# ---- TIFF 基础解码 ---------------------------------------------------------
# TIFF 是二进制格式，IFD 条目里的整数字段长度可为 1/2/4 字节，且可能是
# 大端(MM)或小端(II)。base R 的 readBin 不能直接读无符号 4 字节整数
# （signed=FALSE 仅对 1/2 字节有效），所以 4 字节值先按有符号读再补 2^32。

.decode_uint <- function(raw_value, size, endian) {
  con <- rawConnection(raw_value, open = "rb")
  on.exit(close(con))
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

# IFD 每个条目 12 字节：tag(2) type(2) count(4) value/offset(4)。
# 若数据超过 4 字节，value 字段存的是偏移量而非数据本身，需要再 seek 一次。
.decode_tiff_value <- function(con, type, count, value_field, endian) {
  type_size <- c(`1` = 1, `2` = 1, `3` = 2, `4` = 4, `5` = 8,
                 `6` = 1, `7` = 1, `8` = 2, `9` = 4, `10` = 8,
                 `11` = 4, `12` = 8)
  if (!as.character(type) %in% names(type_size)) return(NA)
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
  # RATIONAL：两个 LONG，前为分子后为分母（分辨率就是这种类型）
  if (type %in% c(5, 10)) {
    vals <- .decode_uint(payload, 4, endian)
    return(vals[seq(1, length(vals), by = 2)] / vals[seq(2, length(vals), by = 2)])
  }
  NA
}

# ---- 解析单个 TIFF ---------------------------------------------------------
parse_tiff <- function(path, expect = list(), allow_compression = 5,
                       tolerance_mm = 0.5) {
  con <- file(path, open = "rb")
  on.exit(close(con))

  byte_order <- rawToChar(.read_raw_at(con, 0, 2))
  endian <- switch(byte_order, II = "little", MM = "big",
                   stop("不是合法 TIFF 字节序标记（应为 II 或 MM）。", call. = FALSE))
  version <- .decode_uint(.read_raw_at(con, 2, 2), 2, endian)[1]
  ifd_offset <- .decode_uint(.read_raw_at(con, 4, 4), 4, endian)[1]
  entry_count <- .decode_uint(.read_raw_at(con, ifd_offset, 2), 2, endian)[1]

  entries <- vector("list", entry_count)
  for (i in seq_len(entry_count)) {
    entry_raw <- .read_raw_at(con, ifd_offset + 2 + (i - 1) * 12, 12)
    entries[[i]] <- list(
      tag = .decode_uint(entry_raw[1:2], 2, endian)[1],
      value = .decode_tiff_value(
        con,
        type = .decode_uint(entry_raw[3:4], 2, endian)[1],
        count = .decode_uint(entry_raw[5:8], 4, endian)[1],
        value_field = entry_raw[9:12],
        endian = endian
      )
    )
  }
  names(entries) <- vapply(entries, function(x) as.character(x$tag), character(1))
  tag <- function(id, default = NA) {
    item <- entries[[as.character(id)]]
    if (is.null(item)) default else item$value
  }

  width_px <- as.numeric(tag(256))[1]
  height_px <- as.numeric(tag(257))[1]
  bits <- as.numeric(tag(258))
  compression <- as.numeric(tag(259))[1]
  photometric <- as.numeric(tag(262))[1]
  samples <- as.numeric(tag(277))[1]
  x_res <- as.numeric(tag(282))[1]
  y_res <- as.numeric(tag(283))[1]
  res_unit <- as.numeric(tag(296))[1]
  extra_samples <- tag(338)

  # ResolutionUnit: 2=inch, 3=centimeter, 1=无单位。3 是常见坑——
  # 此处的数值是 dots/cm，dpi = 数值 × 2.54，物理尺寸也要另算。
  if (identical(res_unit, 2)) {
    x_dpi <- x_res; y_dpi <- y_res
    width_mm <- width_px / x_dpi * 25.4
    height_mm <- height_px / y_dpi * 25.4
    unit_label <- "inch"
  } else if (identical(res_unit, 3)) {
    x_dpi <- x_res * 2.54; y_dpi <- y_res * 2.54
    width_mm <- width_px / x_res * 10
    height_mm <- height_px / y_res * 10
    unit_label <- "centimeter"
  } else {
    x_dpi <- y_dpi <- width_mm <- height_mm <- NA_real_
    unit_label <- "none/unknown"
  }

  # 校验项：前 6 条是期刊硬性要求，与是否给出期望尺寸无关
  checks <- c(
    valid_byte_order = byte_order %in% c("II", "MM"),
    tiff_version_42 = identical(as.numeric(version), 42),
    compression_ok = is.finite(compression) && compression %in% allow_compression,
    eight_bit_per_channel = length(bits) >= 3 && all(bits == 8),
    rgb_photometric = identical(as.numeric(photometric), 2),
    three_samples_per_pixel = identical(as.numeric(samples), 3),
    no_alpha_channel = is.null(extra_samples) || all(!as.numeric(extra_samples) %in% c(1, 2)),
    valid_resolution = is.finite(x_dpi) && is.finite(y_dpi) && x_dpi > 0 && y_dpi > 0
  )

  expected_px <- c(NA_integer_, NA_integer_)
  size_error <- c(NA_real_, NA_real_)
  if (!is.null(expect$width) && !is.null(expect$dpi)) {
    expected_px[1] <- as.integer(floor(expect$width / 25.4 * expect$dpi + 1e-9))
  }
  if (!is.null(expect$height) && !is.null(expect$dpi)) {
    expected_px[2] <- as.integer(floor(expect$height / 25.4 * expect$dpi + 1e-9))
  }
  if (!is.null(expect$width)) {
    size_error[1] <- width_mm - expect$width
    checks <- c(checks, width_mm_matches = is.finite(size_error[1]) &&
                  abs(size_error[1]) < tolerance_mm)
  }
  if (!is.null(expect$height)) {
    size_error[2] <- height_mm - expect$height
    checks <- c(checks, height_mm_matches = is.finite(size_error[2]) &&
                  abs(size_error[2]) < tolerance_mm)
  }
  if (!is.null(expect$dpi)) {
    checks <- c(checks, dpi_matches = is.finite(x_dpi) &&
                  abs(x_dpi - expect$dpi) < 0.5)
    # 像素数允许 ±1 的偏差。原因：ragg 按 floor(mm/25.4*dpi) 取整，而命令行
    # 传入的 mm 常是人工四舍五入值——例如 89mm 单栏 3:2 的真实高度是
    # 59.333mm，若传 59.3，floor 结果就从 1401 变成 1400。1 px 的差异在
    # 600dpi 下仅 0.04mm，不构成期刊合规问题；放宽到 ±1 可避免假报警，
    # 同时仍能抓住真正的尺寸错误（那通常差几十到几百 px）。
    if (is.finite(expected_px[1])) {
      checks <- c(checks, width_px_matches = abs(width_px - expected_px[1]) <= 1)
    }
    if (is.finite(expected_px[2])) {
      checks <- c(checks, height_px_matches = abs(height_px - expected_px[2]) <= 1)
    }
  }

  list(
    path = normalizePath(path, winslash = "/", mustWork = TRUE),
    file = basename(path),
    byte_order = paste0(byte_order, " / ", endian),
    version = version,
    width_px = width_px,
    height_px = height_px,
    bits = bits,
    compression = compression,
    photometric = photometric,
    samples = samples,
    alpha = !(is.null(extra_samples) || all(!as.numeric(extra_samples) %in% c(1, 2))),
    x_dpi = x_dpi,
    y_dpi = y_dpi,
    res_unit_label = unit_label,
    x_res_raw = x_res,
    width_mm = width_mm,
    height_mm = height_mm,
    expected_px = expected_px,
    size_error = size_error,
    size_kb = unname(file.info(path)$size / 1024),
    checks = checks,
    passed = all(checks)
  )
}

print_report <- function(r) {
  row <- function(label, value) cat(sprintf("  %-14s %s\n", label, value))
  cat("\n", strrep("-", 68), "\n", sep = "")
  cat(r$file, "\n", sep = "")
  row("path", r$path)
  row("byte order", r$byte_order)
  row("version", as.character(r$version))
  row("pixels", sprintf("%d x %d", r$width_px, r$height_px))
  row("bits/sample", paste(r$bits, collapse = ","))
  row("compression", sprintf("%d (%s)", r$compression,
                             if (identical(as.numeric(r$compression), 5)) "LZW"
                             else if (identical(as.numeric(r$compression), 1)) "none"
                             else "other"))
  row("photometric", sprintf("%d (%s)", r$photometric,
                             if (identical(as.numeric(r$photometric), 2)) "RGB" else "other"))
  row("alpha", if (r$alpha) "YES (期刊通常不接受)" else "no")
  row("resolution", sprintf("%.4f (per %s)", r$x_res_raw, r$res_unit_label))
  row("effective dpi", sprintf("%.2f x %.2f", r$x_dpi, r$y_dpi))
  row("physical size", sprintf("%.3f x %.3f mm", r$width_mm, r$height_mm))
  if (is.finite(r$expected_px[1]) || is.finite(r$expected_px[2])) {
    row("expected px", sprintf("%s x %s",
                               ifelse(is.finite(r$expected_px[1]), r$expected_px[1], "-"),
                               ifelse(is.finite(r$expected_px[2]), r$expected_px[2], "-")))
  }
  if (is.finite(r$size_error[1]) || is.finite(r$size_error[2])) {
    row("size error", sprintf("%+.3f / %+.3f mm",
                              ifelse(is.finite(r$size_error[1]), r$size_error[1], NA),
                              ifelse(is.finite(r$size_error[2]), r$size_error[2], NA)))
  }
  row("file size", sprintf("%.1f KB", r$size_kb))
  row("verdict", if (r$passed) "PASS" else
    paste0("FAIL -> ", paste(names(r$checks)[!r$checks], collapse = ", ")))
}

to_json <- function(reports) {
  esc <- function(s) gsub('"', '\\\\"', as.character(s))
  item <- function(r) {
    failed <- names(r$checks)[!r$checks]
    failed_json <- if (!length(failed)) "" else
      paste0('"', failed, '"', collapse = ",")
    sprintf(
      '{"file":"%s","pixels":[%d,%d],"dpi":[%.2f,%.2f],"mm":[%.3f,%.3f],"compression":%d,"alpha":%s,"kb":%.1f,"passed":%s,"failed":[%s]}',
      esc(r$file), r$width_px, r$height_px, r$x_dpi, r$y_dpi,
      r$width_mm, r$height_mm, r$compression, tolower(as.character(r$alpha)),
      r$size_kb, tolower(as.character(r$passed)), failed_json
    )
  }
  paste0("[", paste(vapply(reports, item, character(1)), collapse = ","), "]")
}

# ---- CLI -------------------------------------------------------------------
main <- function(argv) {
  if (!length(argv) || any(argv %in% c("-h", "--help"))) {
    cat("用法: Rscript check_tiff_cli.R <file.tiff> [...] [选项]\n",
        "  --width <mm>   期望宽度\n",
        "  --height <mm>  期望高度\n",
        "  --dpi <num>    期望 dpi\n",
        "  --tol <mm>     尺寸容差，默认 0.5\n",
        "  --allow-compression <n[,n]>  默认 5\n",
        "  --json         JSON 输出\n", sep = "")
    return(invisible(0L))
  }
  grab <- function(flag, default = NULL, cast = as.numeric) {
    i <- which(argv == flag)
    if (!length(i)) return(default)
    cast(argv[i[1] + 1])
  }
  expect <- list(width = grab("--width"), height = grab("--height"),
                 dpi = grab("--dpi"))
  tol <- grab("--tol", 0.5)
  allow <- grab("--allow-compression", 5, function(x) as.numeric(strsplit(x, ",")[[1]]))
  as_json <- "--json" %in% argv

  flags_with_value <- c("--width", "--height", "--dpi", "--tol", "--allow-compression")
  skip <- logical(length(argv))
  for (f in flags_with_value) skip <- skip | argv == f | c(FALSE, argv[-length(argv)] == f)
  files <- argv[!skip & !grepl("^--", argv)]

  if (!length(files)) {
    message("未提供 TIFF 文件路径。")
    return(invisible(2L))
  }

  reports <- list()
  for (f in files) {
    reports[[f]] <- tryCatch(
      parse_tiff(f, expect, allow, tol),
      error = function(e) {
        message("读取失败 ", f, "：", conditionMessage(e))
        NULL
      }
    )
  }
  ok <- reports[!vapply(reports, is.null, logical(1))]
  if (!length(ok)) return(invisible(2L))

  if (as_json) {
    cat(to_json(ok), "\n", sep = "")
  } else {
    for (r in ok) print_report(r)
    n_pass <- sum(vapply(ok, `[[`, logical(1), "passed"))
    cat("\n", strrep("=", 68), "\n", sep = "")
    cat(sprintf("共 %d 个文件，通过 %d，失败 %d\n", length(ok), n_pass, length(ok) - n_pass))
    if (length(ok) > 1) {
      cat("\n汇总：\n")
      for (r in ok) {
        cat(sprintf("  %-28s %5d x %-5d %.1f x %.1f mm %7.1f KB  %s\n",
                    r$file, r$width_px, r$height_px, r$width_mm, r$height_mm,
                    r$size_kb, if (r$passed) "PASS" else "FAIL"))
      }
    }
  }
  invisible(if (all(vapply(ok, `[[`, logical(1), "passed"))) 0L else 1L)
}

if (sys.nframe() == 0L) {
  status <- main(commandArgs(trailingOnly = TRUE))
  quit(save = "no", status = status)
}
