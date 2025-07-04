#' @export
format.lint <- function(x, ..., width = getOption("lintr.format_width")) {
  color <- switch(x$type,
    warning = cli::col_magenta,
    error = cli::col_red,
    style = cli::col_blue,
    cli::style_bold
  )
  emph <- cli::style_bold

  line_ref <- build_line_ref(x)
  annotated_msg <- paste0(
    emph(line_ref, ": "),
    color(x$type, ": ", sep = ""),
    "[", x$linter, "] ",
    emph(x$message)
  )

  if (!is.null(width)) {
    annotated_msg <- paste(strwrap(annotated_msg, exdent = 4L, width = width), collapse = "\n")
  }

  paste0(
    annotated_msg, "\n",
    # swap tabs for spaces for #528 (sorry Richard Hendricks)
    chartr("\t", " ", x$line), "\n",
    highlight_string(x$message, x$column_number, x$ranges),
    "\n"
  )
}

build_line_ref <- function(x) {
  line_ref <- paste0(
    x$filename, ":",
    as.character(x$line_number), ":",
    as.character(x$column_number)
  )

  if (!cli::ansi_has_hyperlink_support()) {
    return(line_ref)
  }
  cli::format_inline("{.path {line_ref}}")
}

#' @export
print.lint <- function(x, ...) {
  cat(format(x, ...))
  invisible(x)
}

#' @export
format.lints <- function(x, ..., width = getOption("lintr.format_width")) {
  paste(vapply(x, format, character(1L), width = width), collapse = "\n")
}

#' @export
print.lints <- function(x, ...) {
  use_rstudio_source_markers <- lintr_option("rstudio_source_markers", TRUE) &&
    requireNamespace("rstudioapi", quietly = TRUE) &&
    rstudioapi::hasFun("sourceMarkers")

  github_annotation_project_dir <- lintr_option("github_annotation_project_dir", "")

  if (length(x) > 0L) {
    inline_data <- x[[1L]][["filename"]] == "<text>"
    if (!inline_data && use_rstudio_source_markers) {
      rstudio_source_markers(x)
    } else if (in_github_actions() && !in_pkgdown()) {
      github_actions_log_lints(x, project_dir = github_annotation_project_dir)
    } else {
      lapply(x, print, ...)
    }

    if (isTRUE(settings$error_on_lint)) {
      quit("no", 31L, FALSE) # nocov
    }
  } else {
    # Empty lints
    cli_inform(c(i = "No lints found."))
    if (use_rstudio_source_markers) {
      rstudio_source_markers(x) # clear RStudio source markers
    }
  }

  invisible(x)
}

#' @export
names.lints <- function(x, ...) {
  vapply(x, `[[`, character(1L), "filename")
}

#' @export
split.lints <- function(x, f = NULL, ...) {
  if (is.null(f)) f <- names(x)
  splt <- split.default(x, f)
  for (i in names(splt)) class(splt[[i]]) <- "lints"
  splt
}

#' @export
as.data.frame.lints <- function(x, row.names = NULL, optional = FALSE, ...) { # nolint: object_name. (row.names, #764)
  data.frame(
    filename = vapply(x, `[[`, character(1L), "filename"),
    line_number = vapply(x, `[[`, integer(1L), "line_number"),
    column_number = vapply(x, `[[`, integer(1L), "column_number"),
    type = vapply(x, `[[`, character(1L), "type"),
    message = vapply(x, `[[`, character(1L), "message"),
    line = vapply(x, `[[`, character(1L), "line"),
    linter = vapply(x, `[[`, character(1L), "linter")
  )
}

#' @exportS3Method tibble::as_tibble
as_tibble.lints <- function(x, ..., # nolint: object_name_linter.
                            .rows = NULL,
                            .name_repair = c("check_unique", "unique", "universal", "minimal"),
                            rownames = NULL) {
  stopifnot(requireNamespace("tibble", quietly = TRUE))
  tibble::as_tibble(as.data.frame(x), ..., .rows = .rows, .name_repair = .name_repair, rownames = rownames)
}

#' @exportS3Method data.table::as.data.table
as.data.table.lints <- function(x, keep.rownames = FALSE, ...) { # nolint: object_name_linter.
  stopifnot(requireNamespace("data.table", quietly = TRUE))
  data.table::setDT(as.data.frame(x), keep.rownames = keep.rownames, ...)
}

#' @export
`[.lints` <- function(x, ...) {
  attrs <- attributes(x)
  x <- unclass(x)
  x <- x[...]
  attributes(x) <- attrs
  x
}

#' @export
summary.lints <- function(object, ...) {
  filenames <- vapply(object, `[[`, character(1L), "filename")
  types <- factor(vapply(object, `[[`, character(1L), "type"),
    levels = c("style", "warning", "error")
  )
  tbl <- table(filenames, types)
  filenames <- rownames(tbl)
  res <- as.data.frame.matrix(tbl, row.names = NULL)
  res$filenames <- filenames %||% character()
  nms <- colnames(res)
  res[order(res$filenames), c("filenames", nms[nms != "filenames"])]
}
