## ks_study: a registry of ks_context objects for a whole study, split by
## output type. This is the primary unit passed to ks_chat() and the
## ks_llm workflow, and the unit that save_study()/ks_load() persist.

# ---------------------------------------------------------------------------
# Constructor
# ---------------------------------------------------------------------------

#' Assemble a `ks_study` from a List of Contexts
#'
#' @param contexts Named list of `ks_context` objects (names are output ids).
#' @param meta_dir Character scalar or `NULL`. Source meta folder.
#' @return A `ks_study` object.
#' @keywords internal
#' @noRd
new_ks_study <- function(contexts, meta_dir = NULL) {
  types <- vapply(
    contexts,
    function(ctx) ctx$type %||% "Table",
    character(1)
  )
  structure(
    list(
      tables = contexts[types == "Table"],
      figures = contexts[types == "Figure"],
      texts = contexts[types == "Text"],
      meta_dir = meta_dir
    ),
    class = c("ks_study", "list")
  )
}

# ---------------------------------------------------------------------------
# Predicates, printing, indexing
# ---------------------------------------------------------------------------

#' The `ks_study` Class
#'
#' A `ks_study` is the registry of all compiled outputs of a study, split into
#' `$tables`, `$figures`, and `$texts` (each a named list of [ks_context]
#' objects). Build one with [ks_load()]; persist with [save_study()].
#' `is_ks_study()` tests for the class.
#'
#' @param x An object.
#' @return `TRUE` if `x` is a `ks_study`, otherwise `FALSE`.
#' @aliases ks_study
#' @export
is_ks_study <- function(x) {
  inherits(x, "ks_study")
}

#' Total number of outputs across all types
#' @keywords internal
#' @noRd
.study_n_outputs <- function(study) {
  length(study$tables) + length(study$figures) + length(study$texts)
}

#' All contexts across all types as one flat named list
#' @keywords internal
#' @noRd
.study_all <- function(study) {
  c(study$tables, study$figures, study$texts)
}

#' @export
print.ks_study <- function(x, ...) {
  cli::cli_h1("ks_study")
  cli::cli_text(
    "{length(x$tables)} table{?s}, {length(x$figures)} figure{?s}, {length(x$texts)} text{?s}"
  )
  if (!is.null(x$meta_dir)) {
    cli::cli_text("{.strong Source}: {.path {x$meta_dir}}")
  }
  if (length(x$tables)) {
    cli::cli_h2("Tables")
    ids <- names(x$tables)
    titles <- vapply(x$tables, function(c) {
      if (length(c$title)) c$title[[1]] else c$id
    }, character(1))
    for (i in seq_along(ids)) {
      cli::cli_li("{.strong {ids[[i]]}}: {titles[[i]]}")
    }
  }
  if (length(x$figures)) {
    cli::cli_h2("Figures")
    for (id in names(x$figures)) {
      cli::cli_li("{.strong {id}}")
    }
  }
  invisible(x)
}

#' Look up an output by id across all types
#'
#' @param x A `ks_study`.
#' @param i Character scalar output id.
#' @return The matching `ks_context`, or `NULL`.
#' @export
`[[.ks_study` <- function(x, i) {
  all <- .study_all(x)
  all[[i]]
}

# ---------------------------------------------------------------------------
# Persistence
# ---------------------------------------------------------------------------

#' Save a Study to a `.ks` File
#'
#' Serialises a [ks_study] (with all embedded contexts) to a self-contained
#' JSON file. Reload with [ks_load()]. The original ksTFL meta folder is
#' not needed to reload.
#'
#' @param study A [ks_study] object.
#' @param path Character scalar. Output path; a `.ks` extension is added if
#'   missing.
#'
#' @return Invisibly, the normalised path written.
#'
#' @examples
#' \dontrun{
#' study <- ks_load("path/to/outputs/meta", ids = c("14-3.01"))
#' save_study(study, "my_study.ks")
#' study2 <- ks_load("my_study.ks")
#' }
#'
#' @export
save_study <- function(study, path) {
  if (!is_ks_study(study)) {
    cli::cli_abort("{.arg study} must be a {.cls ks_study} object.")
  }
  checkmate::assert_string(path)
  if (!grepl(paste0("\\.", .KS_STUDY_EXT, "$"), path)) {
    path <- paste0(path, ".", .KS_STUDY_EXT)
  }

  payload <- list(
    meta_dir = study$meta_dir,
    tables = lapply(study$tables, unclass),
    figures = lapply(study$figures, unclass),
    texts = lapply(study$texts, unclass)
  )
  json <- jsonlite::toJSON(payload, auto_unbox = TRUE, null = "null", digits = NA)
  writeLines(json, con = path)

  cli::cli_alert_success("Study saved to {.path {path}}")
  invisible(path)
}

#' Reload a study written by save_study()
#' @keywords internal
#' @noRd
.load_study_file <- function(path) {
  if (!file.exists(path)) {
    cli::cli_abort("Study file not found: {.path {path}}.")
  }
  payload <- tryCatch(
    jsonlite::fromJSON(path, simplifyVector = FALSE),
    error = function(e) NULL
  )
  if (is.null(payload)) {
    cli::cli_abort("Could not parse study file {.path {path}}.")
  }

  restore <- function(lst) {
    lapply(lst, .restore_context)
  }
  study <- structure(
    list(
      tables = restore(payload$tables %||% list()),
      figures = restore(payload$figures %||% list()),
      texts = restore(payload$texts %||% list()),
      meta_dir = payload$meta_dir %||% NULL
    ),
    class = c("ks_study", "list")
  )
  study
}

#' Restore a plain list back into a ks_context, coercing scalar fields
#' @keywords internal
#' @noRd
.restore_context <- function(lst) {
  new_ks_context(
    id = as.character(lst$id %||% NA_character_),
    type = as.character(lst$type %||% "Table"),
    title = as.character(unlist(lst$title) %||% character()),
    subtitles = as.character(unlist(lst$subtitles) %||% character()),
    population = as.character(lst$population %||% NA_character_),
    source = as.character(lst$source %||% NA_character_),
    columns = lst$columns %||% list(),
    span_headers = lst$span_headers %||% list(),
    rows = lst$rows %||% list(),
    n_rows_total = as.integer(lst$n_rows_total %||% 0L),
    footnotes = as.character(unlist(lst$footnotes) %||% character()),
    annotations = lst$annotations %||% list(),
    warnings = as.character(unlist(lst$warnings) %||% character())
  )
}
