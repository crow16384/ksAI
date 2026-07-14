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
#' [load_study()] rather than calling this directly.
#'
#' @param id Character scalar. Stable output identifier (e.g. `"14-3.01"`).
#' @param type Character scalar. One of `"Table"`, `"Figure"`, `"Text"`.
#' @param title Character vector. Title lines.
#' @param population Character scalar. Analysis population, or `NA`.
#' @param source Character scalar. Source program, or `NA`.
#' @param columns List of visible-column descriptors, each a list with
#'   `name`, `label`, `type`, `format_string`.
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
#' them via [load_study()]. `is_ks_context()` tests for the class.
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
# Enrichment (non-mutating overlay)
# ---------------------------------------------------------------------------

#' Enrich a Table Context with User Knowledge
#'
#' Returns a new `ks_context` with user-supplied metadata overlaid. The
#' original object is not modified. `annotations` are merged with any existing
#' annotations rather than replaced.
#'
#' @param ctx A `ks_context` object.
#' @param population Optional character scalar. Overrides the analysis
#'   population.
#' @param source Optional character scalar. Overrides the source program.
#' @param annotations Named list of free-form metadata to merge in.
#'
#' @return A new `ks_context` object.
#'
#' @examples
#' \dontrun{
#' ctx <- study$tables[["14-3.01"]]
#' ctx <- enrich_context(ctx, population = "ITT",
#'                       annotations = list(sap_ref = "Section 9.2"))
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
