#!/usr/bin/env Rscript
# =============================================================================
# bootstrap.R -- locale-safe loader for fig_spec.R
#
# WHY THIS FILE EXISTS
#   fig_spec.R contains Chinese comments encoded in UTF-8. On Windows, if the
#   host sets LC_ALL="C.UTF-8" (a name R does not recognise), R falls back to
#   the C locale. Under the C locale, source(file, encoding = "UTF-8") fails
#   with "invalid input found on input connection", so none of the functions
#   get defined and every later call dies with "could not find function".
#   Setting the locale inside fig_spec.R cannot help: source() parses the whole
#   file before executing any of it. Hence this wrapper.
#
#   This file is deliberately ASCII-only so that it can itself be sourced or
#   parsed under any locale. Do not add non-ASCII characters to it.
#
# USAGE
#   source("scripts/bootstrap.R")     # interactive / RStudio / another script
#   Rscript scripts/bootstrap.R       # load and print an environment report
#
# FUNCTIONS PROVIDED AFTER LOADING
#   fig_spec() theme_pub() save_pub() preview_pub() preview_pair()
#   check_tiff() pt() lw() check_units() register_cjk_font()
#   read_tiff_pixels()
# =============================================================================

local({
  candidates <- c(
    "English_United States.utf8",  # Windows, English UI, UTF-8 codepage
    "en_US.UTF-8",                 # Linux / macOS
    "Chinese_China.utf8",          # Windows, Chinese UI, UTF-8 codepage
    "Chinese_China.936"            # Windows GBK fallback
  )
  for (loc in candidates) {
    ok <- suppressWarnings(Sys.setlocale("LC_ALL", loc))
    if (!is.na(ok) && nzchar(ok)) return(invisible(TRUE))
  }
  warning("Could not set a UTF-8 locale; parsing fig_spec.R may fail.",
          call. = FALSE)
  invisible(FALSE)
})

# Locate this script's directory.
# Order matters: when this file is sourced by another script, commandArgs()
# --file= points at the *entry* script, not at this file. So look for the
# source() frame's ofile first, and only fall back to --file= when this file
# is itself the entry script (Rscript scripts/bootstrap.R).
.this_dir <- function() {
  for (fr in sys.frames()) {
    ofile <- fr$ofile
    if (!is.null(ofile)) {
      return(dirname(normalizePath(ofile, winslash = "/", mustWork = FALSE)))
    }
  }
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- sub("^--file=", "", args[grep("^--file=", args)])
  if (length(file_arg)) {
    return(dirname(normalizePath(file_arg[1], winslash = "/", mustWork = FALSE)))
  }
  getwd()
}

.fig_spec_file <- file.path(.this_dir(), "fig_spec.R")
if (!file.exists(.fig_spec_file)) {
  stop("fig_spec.R not found next to bootstrap.R: ", .fig_spec_file,
       call. = FALSE)
}
source(.fig_spec_file, encoding = "UTF-8")

# When executed directly, print an environment report to speed up diagnosis.
if (sys.nframe() == 0L) {
  cat("R        :", R.version.string, "\n")
  cat("locale   :", Sys.getlocale("LC_CTYPE"), "\n")
  for (p in c("ggplot2", "ragg", "systemfonts", "textshaping")) {
    cat(sprintf("  %-12s %s\n", p,
                tryCatch(as.character(packageVersion(p)),
                         error = function(e) "MISSING")))
  }
  cat("fig_spec() available:", exists("fig_spec"), "\n")
  if (exists("fig_spec")) cat("signature:", deparse(args(fig_spec)), "\n")
}
