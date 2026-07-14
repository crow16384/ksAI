## Import pipeline: read ksTFL metaPath JSON artefacts and compile them into
## a study registry of ks_context objects. JSON-only and offline: no live
## ksTFL TFL_spec session is required.

# ---------------------------------------------------------------------------
# Small parsing helpers
# ---------------------------------------------------------------------------

#' Extract a labelled value from a header/footer band
#'
#' ksTFL stores headers and footers as a list of 3-element rows
#' (`list(left, center, right)`). Clinical programs put `"Population: X"` in a
#' header-left cell and `"Source: prog.R"` in a footer-left cell. This scans
#' every cell of every band for the given prefix and returns the first match.
#'
#' @param bands List of character-3 rows (headers or footers).
#' @param prefix Character scalar, e.g. `"Population"` or `"Source"`.
#' @return Character scalar (trimmed value) or `NA_character_`.
#' @keywords internal
#' @noRd
.parse_labelled <- function(bands, prefix) {
  if (is.null(bands) || length(bands) == 0) {
    return(NA_character_)
  }
  pattern <- paste0("^", prefix, ":\\s*(.+)$")
  for (row in bands) {
    cells <- as.character(unlist(row))
    for (cell in cells) {
      if (grepl(pattern, cell)) {
        return(trimws(sub(pattern, "\\1", cell)))
      }
    }
  }
  NA_character_
}

#' @keywords internal
#' @noRd
.parse_population <- function(headers) {
  .parse_labelled(headers, "Population")
}

#' @keywords internal
#' @noRd
.parse_source <- function(footers) {
  .parse_labelled(footers, "Source")
}

#' Strip HTML markup from a ksTFL column label
#'
#' Labels may contain `<br>`, `<sup>...</sup>` etc. Replace tags with a single
#' space and collapse the result.
#'
#' @param label Character scalar.
#' @return Cleaned character scalar.
#' @keywords internal
#' @noRd
.clean_label <- function(label) {
  if (is.null(label) || length(label) == 0) {
    return("")
  }
  out <- gsub("<[^>]+>", " ", as.character(label))
  out <- gsub("\\s+", " ", out)
  trimws(out)
}

#' Order a named list of text entries by their `$order` and collapse `$text`
#'
#' Used for both titles and footnotes, which share the shape
#' `list(entry_id = list(text = c(...), order = n))`.
#'
#' @param entries Named list of text entries.
#' @return Character vector of text lines in order.
#' @keywords internal
#' @noRd
.extract_text_entries <- function(entries) {
  if (is.null(entries) || length(entries) == 0) {
    return(character())
  }
  orders <- vapply(
    entries,
    function(e) as.numeric(e$order %||% Inf),
    numeric(1)
  )
  entries <- entries[order(orders)]
  out <- unlist(lapply(entries, function(e) as.character(unlist(e$text))))
  if (is.null(out)) character() else unname(out)
}

#' Build the span-header descriptors from a spec's `stubColumns`
#'
#' @param stub_columns Named list of stub entries with `label`, `stubOrder`,
#'   `cols`.
#' @return List of `list(label, cols)` sorted by `stubOrder`.
#' @keywords internal
#' @noRd
.extract_span_headers <- function(stub_columns) {
  if (is.null(stub_columns) || length(stub_columns) == 0) {
    return(list())
  }
  orders <- vapply(
    stub_columns,
    function(s) as.numeric(s$stubOrder %||% Inf),
    numeric(1)
  )
  stub_columns <- stub_columns[order(orders)]
  lapply(stub_columns, function(s) {
    list(
      label = .clean_label(s$label %||% ""),
      cols = as.character(unlist(s$cols))
    )
  })
}

#' Build visible-column descriptors from a spec's `columns`
#'
#' Keeps only columns with `isVisible == TRUE`, preserving `colOrder`.
#'
#' @param columns_spec Named list of column definitions.
#' @return List of `list(name, label, type, format_string)`.
#' @keywords internal
#' @noRd
.extract_columns <- function(columns_spec) {
  if (is.null(columns_spec) || length(columns_spec) == 0) {
    return(list())
  }
  visible <- vapply(
    columns_spec,
    function(col) isTRUE(col$isVisible),
    logical(1)
  )
  columns_spec <- columns_spec[visible]
  if (length(columns_spec) == 0) {
    return(list())
  }
  orders <- vapply(
    columns_spec,
    function(col) as.numeric(col$colOrder %||% Inf),
    numeric(1)
  )
  columns_spec <- columns_spec[order(orders)]
  nms <- names(columns_spec)
  out <- lapply(seq_along(columns_spec), function(i) {
    col <- columns_spec[[i]]
    list(
      name = nms[[i]],
      label = .clean_label(col$label %||% nms[[i]]),
      type = col$format$type %||% "string",
      format_string = col$format$format %||% "%s"
    )
  })
  names(out) <- nms
  out
}

# ---------------------------------------------------------------------------
# Row rendering
# ---------------------------------------------------------------------------

#' Render columnar data JSON into row-wise ks_context rows
#'
#' ksTFL data JSON is columnar (`list(col = c(values))`). This turns it into a
#' list of rows, keeping only visible columns in `$cells` and pulling the
#' invisible control columns (SECTION, ROW_KIND) into per-row metadata.
#'
#' In practice ksTFL emits pre-formatted strings (`type = "string"`,
#' `format = "%s"`), which pass through unchanged. Numeric-typed columns are
#' formatted with the column's `sprintf` format string as a safeguard.
#'
#' @param data_json Named list of equal-length columnar vectors.
#' @param columns_spec Named list of column definitions from the spec.
#' @param max_rows Integer. Maximum rows to embed. Excess rows are dropped and
#'   a warning is recorded (full data remains available via tools).
#' @return `list(rows = <list>, n_rows_total = <int>, warnings = <chr>)`.
#' @keywords internal
#' @noRd
.build_rows <- function(data_json, columns_spec, max_rows = 200L) {
  warnings <- character()

  if (is.null(data_json) || length(data_json) == 0) {
    return(list(rows = list(), n_rows_total = 0L, warnings = warnings))
  }

  n_rows_total <- length(data_json[[1]])
  if (n_rows_total == 0) {
    return(list(rows = list(), n_rows_total = 0L, warnings = warnings))
  }

  visible_cols <- names(columns_spec)[vapply(
    columns_spec, function(col) isTRUE(col$isVisible), logical(1)
  )]
  visible_cols <- intersect(visible_cols, names(data_json))

  section_col <- if ("SECTION" %in% names(data_json)) "SECTION" else NULL
  kind_col <- if ("ROW_KIND" %in% names(data_json)) "ROW_KIND" else NULL

  n_keep <- min(n_rows_total, max_rows)
  if (n_rows_total > max_rows) {
    warnings <- c(warnings, sprintf(
      "Table truncated to %d of %d rows for LLM context; full data available via tools.",
      max_rows, n_rows_total
    ))
  }
  idx <- seq_len(n_keep)

  if (length(visible_cols) == 0) {
    sections <- .cell_vec(data_json, section_col, idx)
    kinds <- .cell_vec(data_json, kind_col, idx)
    rows <- lapply(idx, function(i) {
      list(cells = list(), section = sections[[i]], kind = kinds[[i]])
    })
    return(list(rows = rows, n_rows_total = as.integer(n_rows_total), warnings = warnings))
  }

  # Pre-format each visible column once (vectorised over the kept rows), then
  # assemble rows from a character matrix — far cheaper than per-cell R calls.
  formatted <- lapply(visible_cols, function(col) {
    spec <- columns_spec[[col]]$format
    .format_column(
      data_json[[col]][idx],
      spec$type %||% "string",
      spec$format %||% "%s",
      spec$missings %||% ""
    )
  })
  names(formatted) <- visible_cols

  mat <- do.call(cbind, formatted)
  sections <- .cell_vec(data_json, section_col, idx)
  kinds <- .cell_vec(data_json, kind_col, idx)

  rows <- lapply(idx, function(i) {
    cells_i <- mat[i, ]
    names(cells_i) <- visible_cols
    list(
      cells = as.list(cells_i),
      section = sections[[i]],
      kind = kinds[[i]]
    )
  })

  list(rows = rows, n_rows_total = as.integer(n_rows_total), warnings = warnings)
}

#' Format a raw column (list of scalars) to a character vector
#'
#' Vectorised: coerces the column once, applies the `sprintf` format to numeric
#' columns in a single call, and substitutes the missing token for absent
#' values. Non-numeric values in a numeric column fall back to their string
#' form (as before).
#' @keywords internal
#' @noRd
.format_column <- function(raw, type, fmt, miss) {
  n <- length(raw)
  if (n == 0) {
    return(character())
  }
  # One-pass flatten: length-1 entries become their value; NULL/absent -> NA.
  chr <- rep(NA_character_, n)
  keep <- lengths(raw) == 1L
  if (any(keep)) {
    chr[keep] <- as.character(unlist(raw[keep], use.names = FALSE))
  }
  missing <- is.na(chr)

  if (identical(type, "numeric")) {
    num <- suppressWarnings(as.numeric(chr))
    out <- sprintf(fmt, num)
    nonnum <- is.na(num) & !missing
    out[nonnum] <- chr[nonnum]
  } else {
    out <- chr
  }
  out[missing] <- miss
  out
}

#' Read a control column (SECTION / ROW_KIND) as a character vector
#' @keywords internal
#' @noRd
.cell_vec <- function(data_json, col, idx) {
  if (is.null(col)) {
    return(rep(NA_character_, length(idx)))
  }
  v <- data_json[[col]][idx]
  out <- rep(NA_character_, length(idx))
  keep <- lengths(v) == 1L
  if (any(keep)) {
    out[keep] <- as.character(unlist(v[keep], use.names = FALSE))
  }
  out
}

# ---------------------------------------------------------------------------
# Spec -> ks_context
# ---------------------------------------------------------------------------

#' Compile one spec entry (+ its data) into a `ks_context`
#'
#' @param spec_entry List. A single spec object from the spec JSON (the value
#'   of a `table_spec_*` / `figure_spec_*` / `text_spec_*` key).
#' @param data_json Named list or `NULL`. The columnar data for the spec.
#' @param id Character scalar. The output identifier (from `docFileName`).
#' @param max_rows Integer. Row embedding budget.
#' @return A `ks_context` object.
#' @keywords internal
#' @noRd
.compile_context_from_spec <- function(spec_entry, data_json, id, max_rows = 200L) {
  type <- spec_entry$document$docType %||% "Table"

  columns <- .extract_columns(spec_entry$columns)
  span_headers <- .extract_span_headers(spec_entry$stubColumns)
  title <- .extract_text_entries(spec_entry$titles)
  footnotes <- .extract_text_entries(spec_entry$footnotes)
  population <- .parse_population(spec_entry$headers)
  source <- .parse_source(spec_entry$footers)

  rows <- list()
  n_rows_total <- 0L
  warnings <- character()
  if (identical(type, "Table") && !is.null(data_json)) {
    built <- .build_rows(data_json, spec_entry$columns, max_rows = max_rows)
    rows <- built$rows
    n_rows_total <- built$n_rows_total
    warnings <- built$warnings
  }

  new_ks_context(
    id = id,
    type = type,
    title = title,
    population = population,
    source = source,
    columns = columns,
    span_headers = span_headers,
    rows = rows,
    n_rows_total = n_rows_total,
    footnotes = footnotes,
    annotations = list(),
    warnings = warnings
  )
}

# ---------------------------------------------------------------------------
# File readers
# ---------------------------------------------------------------------------

#' Load a columnar data JSON file by its dataRef
#' @keywords internal
#' @noRd
.load_data_json <- function(meta_dir, data_ref) {
  if (is.null(data_ref) || length(data_ref) == 0) {
    return(NULL)
  }
  ref <- as.character(data_ref[[1]])
  path <- file.path(meta_dir, paste0(ref, ".json"))
  if (!file.exists(path)) {
    return(NULL)
  }
  data <- tryCatch(
    jsonlite::fromJSON(path, simplifyVector = FALSE),
    error = function(e) NULL
  )
  if (is.null(data) || length(data) == 0) {
    return(NULL)
  }
  data
}

#' Derive a stable output id from a document file name
#'
#' `"14-3.01.docx"` -> `"14-3.01"`; `"f-14-01_adas.docx"` -> `"f-14-01_adas"`.
#' @keywords internal
#' @noRd
.doc_id <- function(doc_file) {
  base <- basename(as.character(doc_file %||% ""))
  sub("\\.[^.]+$", "", base)
}

#' Parse one spec JSON file into a list of `ks_context` objects
#'
#' @param spec_json_path Character scalar. Path to a `<hash>.json` spec file.
#' @param meta_dir Character scalar. Folder containing the data JSON files.
#' @param max_rows Integer. Row embedding budget.
#' @return Named list of `ks_context` objects (names are output ids). Empty
#'   list if the file is not a valid spec.
#' @keywords internal
#' @noRd
.parse_spec_json <- function(spec_json_path, meta_dir, max_rows = 200L) {
  doc <- tryCatch(
    jsonlite::fromJSON(spec_json_path, simplifyVector = FALSE),
    error = function(e) NULL
  )
  if (is.null(doc) || is.null(doc[["_metadata"]])) {
    return(list())
  }

  base_id <- .doc_id(doc[["_metadata"]][["docFileName"]])
  spec_keys <- setdiff(names(doc), "_metadata")

  out <- list()
  for (k in seq_along(spec_keys)) {
    key <- spec_keys[[k]]
    spec_entry <- doc[[key]]
    data_json <- .load_data_json(meta_dir, spec_entry$dataRef)
    # Disambiguate when one spec file holds several outputs.
    id <- if (length(spec_keys) == 1) base_id else paste0(base_id, "_", k)
    ctx <- .compile_context_from_spec(spec_entry, data_json, id, max_rows = max_rows)
    out[[id]] <- ctx
  }
  out
}

.filter_contexts <- function(contexts, pattern, ignore_case = TRUE) {
  if (is.null(pattern)) {
    return(contexts)
  }

  # Validate once so malformed regexes fail fast with a clear error.
  tryCatch(
    grepl(pattern, "", ignore.case = ignore_case, perl = TRUE),
    warning = function(w) {
      cli::cli_abort(c(
        "Invalid {.arg pattern} regular expression.",
        x = "{conditionMessage(w)}"
      ))
    },
    error = function(e) {
      cli::cli_abort(c(
        "Invalid {.arg pattern} regular expression.",
        x = "{conditionMessage(e)}"
      ))
    }
  )

  keep <- vapply(
    contexts,
    function(ctx) {
      fields <- c(
        as.character(ctx$id %||% ""),
        as.character(ctx$type %||% ""),
        as.character(ctx$title %||% character())
      )
      any(grepl(pattern, fields, ignore.case = ignore_case, perl = TRUE), na.rm = TRUE)
    },
    logical(1)
  )

  contexts[keep]
}

# ---------------------------------------------------------------------------
# Public entry point (folder branch)
# ---------------------------------------------------------------------------

#' Load a Study from a ksTFL Meta Folder or a Saved `.ks` File
#'
#' Reads the metadata and data JSON artefacts produced by
#' [ksTFL::save_report()] and compiles them into a [ks_study] registry of
#' [ks_context] objects. Alternatively, reloads a study previously written by
#' [save_study()].
#'
#' @param path Character scalar. Either a ksTFL meta folder (containing
#'   `_index.json` and the spec/data JSON files) or a `.ks` file produced by
#'   [save_study()].
#' @param latest_only Logical. When reading a meta folder, keep only the most
#'   recent spec per document (via `is_latest`). Default `TRUE`.
#' @param max_rows Integer. Maximum data rows embedded per table context.
#'   Defaults to `ks_get_option("max_rows")`.
#' @param pattern Optional regular expression. When set, keeps only outputs
#'   whose id, type, or title matches the pattern.
#' @param ignore_case Logical. Passed to [base::grepl()] when matching
#'   `pattern`. Default `TRUE`.
#'
#' @return A [ks_study] object.
#'
#' @examples
#' \dontrun{
#' study <- load_study("path/to/outputs/meta")
#' study
#' study$tables[["14-3.01"]]
#' }
#'
#' @export
load_study <- function(path,
                       latest_only = TRUE,
                       max_rows = ks_get_option("max_rows"),
                       pattern = NULL,
                       ignore_case = TRUE) {
  checkmate::assert_string(path)
  checkmate::assert_string(pattern, null.ok = TRUE)
  checkmate::assert_flag(ignore_case)

  # .ks file branch (defined in study.R).
  if (grepl(paste0("\\.", .KS_STUDY_EXT, "$"), path)) {
    loaded <- .load_study_file(path)
    contexts <- .study_all(loaded)
    contexts <- .filter_contexts(contexts, pattern = pattern, ignore_case = ignore_case)

    if (length(contexts) == 0) {
      cli::cli_abort(c(
        "No outputs matched {.arg pattern} in {.file {path}}.",
        i = "Try a broader regular expression or set {.code pattern = NULL}."
      ))
    }

    return(new_ks_study(contexts, meta_dir = loaded$meta_dir))
  }

  if (!dir.exists(path)) {
    cli::cli_abort(c(
      "Meta folder not found: {.path {path}}.",
      i = "Pass a ksTFL meta folder or a {.file .ks} file."
    ))
  }

  index <- ksTFL::list_reports(path)
  if (is.null(index) || nrow(index) == 0) {
    cli::cli_abort("No reports found in meta folder {.path {path}}.")
  }
  if (latest_only && "is_latest" %in% names(index)) {
    index <- index[isTRUE(index$is_latest) | index$is_latest %in% TRUE, , drop = FALSE]
  }

  spec_files <- unique(as.character(index$spec_file))
  contexts <- list()
  for (sf in spec_files) {
    spec_path <- file.path(path, sf)
    if (!file.exists(spec_path)) next
    parsed <- .parse_spec_json(spec_path, path, max_rows = max_rows)
    contexts <- c(contexts, parsed)
  }

  contexts <- .filter_contexts(contexts, pattern = pattern, ignore_case = ignore_case)

  if (length(contexts) == 0) {
    if (is.null(pattern)) {
      cli::cli_abort("No table/figure/text specs could be parsed from {.path {path}}.")
    } else {
      cli::cli_abort(c(
        "No outputs matched {.arg pattern} in {.path {path}}.",
        i = "Try a broader regular expression or set {.code pattern = NULL}."
      ))
    }
  }

  new_ks_study(contexts, meta_dir = path)
}
