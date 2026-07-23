## ks_context: the self-contained, LLM-ready representation of one ksTFL output.
##
## A ks_context is the render-join of a ksTFL specification and its data: it
## embeds the structural metadata (titles, columns, footnotes, span headers)
## together with the rendered rows (already-formatted cell strings). Once
## compiled it does not need the original spec or data JSON to be useful.

# ---------------------------------------------------------------------------
# Constructor
# ---------------------------------------------------------------------------

#' Create a `ks_context` Object
#'
#' Low-level constructor. Most users obtain `ks_context` objects via
#' [ks_load()] rather than calling this directly.
#'
#' @param id Character scalar. Stable output identifier (e.g. `"14-3.01"`).
#' @param type Character scalar. One of `"Table"`, `"Figure"`, `"Text"`.
#' @param title Character vector. Title lines.
#' @param subtitles Character vector. Subtitle lines.
#' @param population Character scalar. Analysis population, or `NA`.
#' @param source Character scalar. Source program, or `NA`.
#' @param columns List of visible-column descriptors, each a list with
#'   `name`, `label`, `type`, `format_string`, `is_grouping`.
#' @param span_headers List of span-header descriptors, each with `label`
#'   and `cols`.
#' @param rows List of rendered rows, each with `cells`, `section`, `kind`.
#' @param n_rows_total Integer. Total rows before any truncation.
#' @param footnotes Character vector. Footnote lines.
#' @param annotations Named list of free-form user metadata.
#' @param warnings Character vector. Compilation warnings.
#'
#' @return An object of class `ks_context`.
#' @keywords internal
#' @noRd
new_ks_context <- function(id,
                           type,
                           title = character(),
                           subtitles = character(),
                           population = NA_character_,
                           source = NA_character_,
                           columns = list(),
                           span_headers = list(),
                           rows = list(),
                           n_rows_total = 0L,
                           footnotes = character(),
                           annotations = list(),
                           warnings = character()) {
  structure(
    list(
      id = id,
      type = type,
      title = title,
      subtitles = subtitles,
      population = population,
      source = source,
      columns = columns,
      span_headers = span_headers,
      rows = rows,
      n_rows_total = as.integer(n_rows_total),
      footnotes = footnotes,
      annotations = annotations,
      warnings = warnings
    ),
    class = c("ks_context", "list")
  )
}

# ---------------------------------------------------------------------------
# Predicates & printing
# ---------------------------------------------------------------------------

#' The `ks_context` Class
#'
#' A `ks_context` is the render-join of one ksTFL output's specification and
#' its data: a self-contained, LLM-ready object holding the title, analysis
#' population, columns, span headers, rendered rows, and footnotes. Obtain
#' them via [ks_load()]. `is_ks_context()` tests for the class.
#'
#' @param x An object.
#' @return `TRUE` if `x` is a `ks_context`, otherwise `FALSE`.
#' @aliases ks_context
#' @export
is_ks_context <- function(x) {
  inherits(x, "ks_context")
}

#' @export
print.ks_context <- function(x, ...) {
  cli::cli_h1("ks_context: {x$id} ({x$type})")
  if (length(x$title)) {
    cli::cli_text("{.strong Title}: {paste(x$title, collapse = ' \u2014 ')}")
  }
  if (length(x$subtitles)) {
    cli::cli_text("{.strong Subtitles}: {paste(x$subtitles, collapse = ' \u2014 ')}")
  }
  if (!is.na(x$population)) {
    cli::cli_text("{.strong Population}: {x$population}")
  }
  if (!is.na(x$source)) {
    cli::cli_text("{.strong Source}: {x$source}")
  }
  if (length(x$columns)) {
    labs <- vapply(x$columns, function(col) col$label %||% col$name, character(1))
    cli::cli_text("{.strong Columns} ({length(x$columns)}): {paste(labs, collapse = ', ')}")
  }
  if (length(x$span_headers)) {
    sp <- vapply(x$span_headers, function(s) s$label %||% "", character(1))
    cli::cli_text("{.strong Span headers}: {paste(sp, collapse = ', ')}")
  }
  cli::cli_text("{.strong Rows}: {length(x$rows)} shown of {x$n_rows_total} total")
  if (length(x$footnotes)) {
    cli::cli_text("{.strong Footnotes}: {length(x$footnotes)}")
  }
  if (length(x$annotations)) {
    cli::cli_text("{.strong Annotations}: {paste(names(x$annotations), collapse = ', ')}")
  }
  if (length(x$warnings)) {
    cli::cli_alert_warning("{length(x$warnings)} warning{?s}")
  }
  invisible(x)
}

# ---------------------------------------------------------------------------
# JSON view (for prompt injection and tools)
# ---------------------------------------------------------------------------

#' Render a `ks_context` as a JSON String
#'
#' Produces the compact JSON representation of a table context used for prompt
#' injection and by the registered LLM tools.
#'
#' @param x A `ks_context` object.
#' @param pretty Logical. Pretty-print the JSON. Default `FALSE`.
#'
#' @return A length-1 character string of JSON.
#' @export
as_json <- function(x, pretty = FALSE) {
  UseMethod("as_json")
}

#' @export
as_json.ks_context <- function(x, pretty = FALSE) {
  jsonlite::toJSON(unclass(x), auto_unbox = TRUE, pretty = pretty, null = "null")
}

# ---------------------------------------------------------------------------
# Markdown view (for prompt injection — human-readable, model-friendly)
# ---------------------------------------------------------------------------

#' Render a `ks_context` as a Human-Readable Markdown Table
#'
#' Reconstructs the output the way a reader sees it: real column labels (not
#' raw column codes), treatment-arm/span-header groups, section-grouped rows,
#' and footnotes. This is the representation injected into single-output skill
#' prompts, because models describe a rendered table far more richly than the
#' machine-shaped JSON produced by [as_json()].
#'
#' @param x A `ks_context` object.
#' @param ... Unused; for S3 compatibility.
#'
#' @return A length-1 character string of Markdown.
#'
#' @examples
#' \dontrun{
#' study <- ks_load("path/to/outputs/meta", ids = c("14-3.01"))
#' cat(as_markdown(study[["14-3.01"]]))
#' }
#'
#' @export
as_markdown <- function(x, ...) {
  UseMethod("as_markdown")
}

#' @export
as_markdown.ks_context <- function(x, ...) {
  lines <- character()

  # Title lines.
  if (length(x$title)) {
    lines <- c(lines, paste0("# ", x$title[[1]]))
    if (length(x$title) > 1) {
      lines <- c(lines, vapply(x$title[-1], function(t) paste0("_", t, "_"), character(1)))
    }
  }

  # Metadata block.
  meta <- c(
    paste0("- **ID**: ", x$id),
    paste0("- **Type**: ", x$type)
  )
  if (!is.na(x$population)) meta <- c(meta, paste0("- **Population**: ", x$population))
  if (!is.na(x$source)) meta <- c(meta, paste0("- **Source**: ", x$source))
  lines <- c(lines, "", meta)

  cols <- x$columns
  has_table <- length(cols) > 0 && length(x$rows) > 0

  if (!has_table) {
    note <- if (!identical(x$type, "Table")) {
      paste0("_(", x$type, " output; no tabular data embedded.)_")
    } else {
      "_(No data rows available.)_"
    }
    lines <- c(lines, "", note)
    lines <- c(lines, .md_footnotes(x$footnotes))
    return(paste(lines, collapse = "\n"))
  }

  col_names <- vapply(cols, function(c) c$name, character(1))
  col_labels <- vapply(cols, function(c) {
    lab <- c$label
    if (is.null(lab) || !nzchar(lab)) c$name else lab
  }, character(1))
  name_to_label <- stats::setNames(col_labels, col_names)

  # Treatment-arm / span-header groups, mapped to human labels.
  if (length(x$span_headers)) {
    spans <- vapply(x$span_headers, function(s) {
      lbls <- unname(name_to_label[s$cols])
      lbls[is.na(lbls)] <- s$cols[is.na(lbls)]
      paste0(s$label, " (", paste(lbls, collapse = ", "), ")")
    }, character(1))
    lines <- c(lines, "", paste0("**Column groups**: ", paste(spans, collapse = "; ")))
  }

  # Header + separator.
  lines <- c(
    lines,
    "",
    paste0("| ", paste(.md_escape(col_labels), collapse = " | "), " |"),
    paste0("| ", paste(rep("---", length(col_labels)), collapse = " | "), " |")
  )

  # Body rows, with section subheaders inserted on change.
  prev_section <- NULL
  n_col <- length(col_names)
  for (row in x$rows) {
    sec <- row$section
    if (!is.null(sec) && !is.na(sec) && nzchar(sec) && !identical(prev_section, sec)) {
      secrow <- c(paste0("**", .md_escape(sec), "**"), rep("", n_col - 1))
      lines <- c(lines, paste0("| ", paste(secrow, collapse = " | "), " |"))
      prev_section <- sec
    }
    cells <- vapply(col_names, function(nm) {
      v <- row$cells[[nm]]
      if (is.null(v) || (length(v) == 1 && is.na(v))) "" else as.character(v)
    }, character(1))
    cells <- .md_escape(cells)
    if (identical(row$kind, "label") && nzchar(cells[[1]])) {
      cells[[1]] <- paste0("**", cells[[1]], "**")
    }
    lines <- c(lines, paste0("| ", paste(cells, collapse = " | "), " |"))
  }

  # Truncation note.
  shown <- length(x$rows)
  if (x$n_rows_total > shown) {
    lines <- c(lines, "", sprintf("_Showing %d of %d rows._", shown, x$n_rows_total))
  }

  lines <- c(lines, .md_footnotes(x$footnotes))
  paste(lines, collapse = "\n")
}

# ---------------------------------------------------------------------------
# Compact DSL view (token-efficient prompt injection)
# ---------------------------------------------------------------------------

#' Render a `ks_context` as Compact DSL Text
#'
#' Produces a token-efficient text representation of a table context for LLM
#' prompt injection. Column names are not repeated per cell; span headers group
#' measure columns, and sections appear as bracketed headers.
#'
#' @param x A `ks_context` (or later `ks_facts`) object.
#' @param ... Unused; for S3 compatibility.
#'
#' @return A length-1 character string.
#'
#' @examples
#' \dontrun{
#' study <- ks_load("path/to/outputs/meta", ids = c("14-3.01"))
#' cat(as_compact(study[["14-3.01"]]))
#' }
#'
#' @export
as_compact <- function(x, ...) {
  UseMethod("as_compact")
}

#' @export
as_compact.ks_context <- function(x, ...) {
  lines <- .compact_header_block(x)

  cols <- x$columns
  has_table <- length(cols) > 0 && length(x$rows) > 0

  if (!has_table) {
    note <- if (!identical(x$type, "Table")) {
      paste0("(", x$type, " output; no tabular data embedded.)")
    } else {
      "(No data rows available.)"
    }
    lines <- c(lines, "", note)
    lines <- c(lines, .compact_footnotes(x$footnotes))
    return(paste(lines, collapse = "\n"))
  }

  lines <- c(lines, "", .compact_rows_block(x))
  lines <- c(lines, .compact_footnotes(x$footnotes))
  paste(lines, collapse = "\n")
}

#' Compact header: TABLE / TITLE / SUBTITLE lines
#' @keywords internal
#' @noRd
.compact_header_block <- function(x) {
  header <- paste0("TABLE: ", x$id)
  if (!is.na(x$population) && nzchar(x$population)) {
    header <- paste0(header, " | Population: ", x$population)
  }
  lines <- header

  if (length(x$title)) {
    lines <- c(lines, paste0("TITLE: ", paste(x$title, collapse = " \u2014 ")))
  }
  if (length(x$subtitles)) {
    lines <- c(lines, paste0("SUBTITLE: ", paste(x$subtitles, collapse = " \u2014 ")))
  }
  lines
}

#' Compact body rows with optional span grouping
#' @keywords internal
#' @noRd
.compact_rows_block <- function(x) {
  cols <- x$columns
  if (!length(cols)) {
    return(character())
  }
  col_names <- vapply(cols, function(c) c$name, character(1))
  col_labels <- vapply(cols, function(c) {
    lab <- c$label
    if (is.null(lab) || !nzchar(lab)) c$name else lab
  }, character(1))

  row_label_col <- col_names[[1]]
  measure_cols <- if (length(col_names) > 1L) col_names[-1] else character()
  measure_labels <- if (length(col_labels) > 1L) col_labels[-1] else character()
  name_to_label <- stats::setNames(col_labels, col_names)

  cell_val <- function(row, nm) {
    v <- row$cells[[nm]]
    if (is.null(v) || (length(v) == 1 && is.na(v))) "" else as.character(v)
  }

  if (length(x$span_headers)) {
    .compact_rows_spanned(
      x$rows, row_label_col, x$span_headers, name_to_label, cell_val
    )
  } else {
    .compact_rows_flat(
      x$rows, row_label_col, measure_cols, measure_labels, cell_val
    )
  }
}

#' Resolve a column name to its display label, falling back to the name.
#'
#' Span headers may reference columns that are not visible (filtered out of
#' `ks_context$columns`). Atomic `[[` lookup throws on missing names; this
#' helper never does.
#' @keywords internal
#' @noRd
.col_label_or_name <- function(name_to_label, nm) {
  nm <- as.character(nm %||% "")
  if (!nzchar(nm)) {
    return("")
  }
  if (!nm %in% names(name_to_label)) {
    return(nm)
  }
  lab <- unname(name_to_label[[nm]])
  if (is.null(lab) || is.na(lab) || !nzchar(lab)) nm else as.character(lab)
}

#' Span-grouped compact rows
#'
#' Emits a one-time SPANS/COLS legend, then short keys per row so long arm
#' labels are not repeated on every line.
#' @keywords internal
#' @noRd
.compact_rows_spanned <- function(rows, row_label_col, span_headers,
                                  name_to_label, cell_val) {
  n_spans <- length(span_headers)
  keys <- if (n_spans <= 26L) {
    LETTERS[seq_len(n_spans)]
  } else {
    paste0("S", seq_len(n_spans))
  }

  lines <- character()
  # Legend: A = Placebo (N=86); B = ...
  legend <- paste(
    vapply(seq_len(n_spans), function(i) {
      paste0(keys[[i]], "=", span_headers[[i]]$label)
    }, character(1)),
    collapse = "; "
  )
  lines <- c(lines, paste0("SPANS: ", legend))

  # Keep only columns that exist in the context (or still show the name).
  # Prefer visible measure cols when a span mixes visible + invisible refs.
  visible <- names(name_to_label)
  span_col_lists <- lapply(span_headers, function(span) {
    cols <- as.character(span$cols %||% character())
    keep <- intersect(cols, visible)
    if (length(keep)) keep else cols
  })

  # Shared measure labels within the first span (typical stub layout).
  # If spans differ, list COLS per span key.
  col_sets <- lapply(span_col_lists, function(cols) {
    vapply(cols, function(nm) .col_label_or_name(name_to_label, nm), character(1))
  })
  same_cols <- length(unique(lapply(col_sets, paste, collapse = "\1"))) == 1L
  if (same_cols && length(col_sets[[1]])) {
    lines <- c(lines, paste0("COLS: ", paste(col_sets[[1]], collapse = ", ")))
  } else if (length(col_sets) && any(lengths(col_sets) > 0)) {
    per <- vapply(seq_len(n_spans), function(i) {
      paste0(keys[[i]], ":(", paste(col_sets[[i]], collapse = ", "), ")")
    }, character(1))
    lines <- c(lines, paste0("COLS: ", paste(per, collapse = "; ")))
  }

  prev_section <- NULL
  for (row in rows) {
    sec <- row$section
    if (!is.null(sec) && !is.na(sec) && nzchar(sec) && !identical(prev_section, sec)) {
      lines <- c(lines, paste0("[", sec, "]"))
      prev_section <- sec
    }

    label <- cell_val(row, row_label_col)
    span_parts <- vapply(seq_len(n_spans), function(i) {
      cols_i <- span_col_lists[[i]]
      if (!length(cols_i)) {
        return(paste0(keys[[i]], ":"))
      }
      vals <- vapply(cols_i, function(nm) cell_val(row, nm), character(1))
      paste0(keys[[i]], ": ", paste(vals, collapse = ", "))
    }, character(1))

    lines <- c(lines, paste0(label, ":  ", paste(span_parts, collapse = "  |  ")))
  }
  lines
}

#' Flat (no span) compact rows
#' @keywords internal
#' @noRd
.compact_rows_flat <- function(rows, row_label_col, measure_cols,
                               measure_labels, cell_val) {
  lines <- character()
  if (length(measure_labels)) {
    lines <- c(lines, paste0("COLS: ", paste(measure_labels, collapse = " | ")))
  }

  prev_section <- NULL
  for (row in rows) {
    sec <- row$section
    if (!is.null(sec) && !is.na(sec) && nzchar(sec) && !identical(prev_section, sec)) {
      lines <- c(lines, paste0("[", sec, "]"))
      prev_section <- sec
    }
    label <- cell_val(row, row_label_col)
    vals <- vapply(measure_cols, function(nm) cell_val(row, nm), character(1))
    if (length(vals)) {
      lines <- c(lines, paste0(label, ": ", paste(vals, collapse = " | ")))
    } else {
      lines <- c(lines, label)
    }
  }
  lines
}

#' Compact footnote block
#' @keywords internal
#' @noRd
.compact_footnotes <- function(footnotes) {
  if (!length(footnotes)) {
    return(character())
  }
  c("", "Footnotes:", vapply(footnotes, function(f) paste0("- ", f), character(1)))
}

#' Escape Markdown table-breaking characters in cell text
#' @keywords internal
#' @noRd
.md_escape <- function(v) {
  v <- gsub("|", "\\|", v, fixed = TRUE)
  gsub("[\r\n]+", " ", v)
}

#' Render footnotes as trailing Markdown lines (empty if none)
#' @keywords internal
#' @noRd
.md_footnotes <- function(footnotes) {
  if (!length(footnotes)) {
    return(character())
  }
  c("", "**Footnotes:**", vapply(footnotes, function(f) paste0("- ", f), character(1)))
}

# ---------------------------------------------------------------------------
# Enrichment (non-mutating overlay)
# ---------------------------------------------------------------------------

#' Enrich a Table Context with User Knowledge
#'
#' Returns a new `ks_context` with user-supplied metadata overlaid. The
#' original object is not modified. `annotations` are merged with any existing
#' annotations rather than replaced.
#'
#' Set `annotations = list(domain = "AE")` (or any study-specific code) to
#' override automatic domain inference used by [as_capsules()]. Domain tags
#' are language-agnostic: multilingual titles, MedDRA structure, ICH-style
#' ids, and [ks_set_option()] `domain_map` are also consulted.
#'
#' @param ctx A `ks_context` object.
#' @param population Optional character scalar. Overrides the analysis
#'   population.
#' @param source Optional character scalar. Overrides the source program.
#' @param annotations Named list of free-form metadata to merge in.
#'   Use `domain` to force the capsule domain code.
#'
#' @return A new `ks_context` object.
#'
#' @examples
#' \dontrun{
#' ctx <- study$tables[["14-3.01"]]
#' ctx <- enrich_context(ctx, population = "ITT",
#'                       annotations = list(sap_ref = "Section 9.2",
#'                                          domain = "EFFC"))
#' }
#'
#' @export
enrich_context <- function(ctx,
                           population = NULL,
                           source = NULL,
                           annotations = list()) {
  if (!is_ks_context(ctx)) {
    cli::cli_abort("{.arg ctx} must be a {.cls ks_context} object.")
  }
  if (!is.null(population)) {
    checkmate::assert_string(population)
    ctx$population <- population
  }
  if (!is.null(source)) {
    checkmate::assert_string(source)
    ctx$source <- source
  }
  if (length(annotations)) {
    if (is.null(names(annotations)) || any(names(annotations) == "")) {
      cli::cli_abort("{.arg annotations} must be a fully named list.")
    }
    ctx$annotations <- utils::modifyList(ctx$annotations, annotations)
  }
  ctx
}

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

#' @keywords internal
#' @noRd
`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}
