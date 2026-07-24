#' ksAI: AI-Native Reasoning Layer for ksTFL Clinical Outputs
#'
#' ksAI reads the metadata and data JSON artefacts produced by
#' [ksTFL::save_report()], compiles them into a self-contained study registry
#' of table contexts ([ks_study] of [ks_context] objects), and provides an
#' [ellmer][ellmer::ellmer]-backed chat plus skill-driven prompting over a
#' targeted subset of outputs so a medical writer can reason across selected
#' study statistical results and draft clinical study report (CSR) narratives.
#'
#' @keywords internal
#' @useDynLib ksAI, .registration = TRUE
#' @importFrom Rcpp evalCpp
"_PACKAGE"

# ---------------------------------------------------------------------------
# Package-local option store
# ---------------------------------------------------------------------------

# Internal environment holding runtime options. Not exported.
.ksai_opts <- new.env(parent = emptyenv())

#' @keywords internal
#' @noRd
.ksai_default_options <- function() {
  list(
    # Maximum data rows embedded per table context.
    max_rows = 200L,
    # Directory of user-defined skill prompts (.md). NULL = built-ins only.
    skills_dir = NULL,
    # Default LLM provider for ks_chat().
    provider = "ollama",
    # Context serialization for LLM injection: "markdown", "compact", or "json".
    context_format = "markdown",
    # Default embedding model for capsule semantic retrieval.
    embed_model = "text-embedding-nomic-embed-text-v1.5",
    # OpenAI-compatible embeddings endpoint.
    embed_url = "http://127.0.0.1:1234/v1"
  )
}

#' @noRd
.onLoad <- function(libname, pkgname) {
  defaults <- .ksai_default_options()
  for (key in names(defaults)) {
    if (is.null(.ksai_opts[[key]])) {
      assign(key, defaults[[key]], envir = .ksai_opts)
    }
  }
  invisible(NULL)
}

#' Get or Set ksAI Options
#'
#' `ks_get_option()` retrieves a package option; `ks_set_option()` updates one
#' or more options for the current session.
#'
#' @param key Character scalar. Option name. One of `"max_rows"`,
#'   `"skills_dir"`, `"provider"`, `"context_format"`, `"embed_model"`,
#'   `"embed_url"`.
#' @param ... Named `key = value` pairs to set (for `ks_set_option()`).
#'
#' @return `ks_get_option()` returns the option value. `ks_set_option()`
#'   invisibly returns the previous values of the changed options.
#'
#' @examples
#' ks_get_option("max_rows")
#' old <- ks_set_option(max_rows = 300L)
#' ks_set_option(!!!old)
#'
#' @export
ks_get_option <- function(key) {
  checkmate::assert_string(key)
  valid <- names(.ksai_default_options())
  if (!key %in% valid) {
    cli::cli_abort(c(
      "Unknown option {.val {key}}.",
      i = "Valid options: {.val {valid}}."
    ))
  }
  get0(key, envir = .ksai_opts, ifnotfound = .ksai_default_options()[[key]])
}

#' @rdname ks_get_option
#' @export
ks_set_option <- function(...) {
  args <- rlang::list2(...)
  if (length(args) == 0) {
    return(invisible(list()))
  }
  if (is.null(names(args)) || any(names(args) == "")) {
    cli::cli_abort("All arguments to {.fn ks_set_option} must be named.")
  }
  valid <- names(.ksai_default_options())
  unknown <- setdiff(names(args), valid)
  if (length(unknown) > 0) {
    cli::cli_abort(c(
      "Unknown option{?s}: {.val {unknown}}.",
      i = "Valid options: {.val {valid}}."
    ))
  }
  previous <- lapply(names(args), ks_get_option)
  names(previous) <- names(args)
  for (key in names(args)) {
    assign(key, args[[key]], envir = .ksai_opts)
  }
  invisible(previous)
}
