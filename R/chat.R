## ks_chat: wrap an ellmer Chat around a study, choosing a context strategy
## based on study size.
##
## Small studies (<= ks_get_option("study_threshold")) inject every table
## context directly into the system prompt. Larger studies inject a compact
## index and register tools so the model can retrieve details on demand.

# ---------------------------------------------------------------------------
# Compact study index
# ---------------------------------------------------------------------------

#' Build a compact markdown index of all study outputs
#'
#' @param study A `ks_study`.
#' @return A length-1 markdown string with one table row per output.
#' @keywords internal
#' @noRd
.build_compact_index <- function(study) {
  all <- .study_all(study)
  if (length(all) == 0) {
    return("_(empty study)_")
  }
  header <- "| ID | Title | Type | Population | Rows |\n|----|-------|------|------------|------|"
  lines <- vapply(all, function(ctx) {
    title <- if (length(ctx$title)) paste(ctx$title, collapse = " ") else ctx$id
    title <- gsub("|", "/", title, fixed = TRUE)
    pop <- if (is.na(ctx$population)) "" else ctx$population
    sprintf(
      "| %s | %s | %s | %s | %d |",
      ctx$id, title, ctx$type, pop, ctx$n_rows_total
    )
  }, character(1))
  paste(c(header, lines), collapse = "\n")
}

#' Build the full system prompt for a study, given the chosen mode
#' @keywords internal
#' @noRd
.build_system_prompt <- function(study, mode) {
  base <- .load_prompt(.KS_SYSTEM_PROMPT)

  if (identical(mode, "small")) {
    contexts <- .concat_contexts(.study_all(study))
    study_context <- paste0(
      "## Study outputs (full contexts)\n\n",
      "All ", .study_n_outputs(study), " study outputs are provided below as JSON.\n\n",
      "```json\n", contexts, "\n```"
    )
  } else {
    index_tmpl <- .load_prompt(.KS_STUDY_INDEX_PROMPT)
    study_context <- .fill_prompt(index_tmpl, index = .build_compact_index(study))
  }

  .fill_prompt(base, study_context = study_context)
}

# ---------------------------------------------------------------------------
# Provider dispatch
# ---------------------------------------------------------------------------

#' Construct the underlying ellmer Chat for a provider
#' @keywords internal
#' @noRd
.make_ellmer_chat <- function(provider, model, system_prompt, base_url, echo, ...) {
  args <- list(
    system_prompt = system_prompt,
    model = model,
    echo = echo,
    ...
  )
  if (!is.null(base_url)) {
    args$base_url <- base_url
  }

  ctor <- switch(
    provider,
    ollama = ellmer::chat_ollama,
    lm_studio = ellmer::chat_lmstudio,
    lmstudio = ellmer::chat_lmstudio,
    openai = ellmer::chat_openai,
    anthropic = ellmer::chat_anthropic,
    {
      supported <- .KS_PROVIDERS
      cli::cli_abort(c(
        "Unknown provider {.val {provider}}.",
        i = "Supported: {.val {supported}}."
      ))
    }
  )
  do.call(ctor, args)
}

# ---------------------------------------------------------------------------
# Public constructor
# ---------------------------------------------------------------------------

#' Open an AI Chat Session Over a Study
#'
#' Creates an [ellmer][ellmer::ellmer] chat wired to a study. The context
#' strategy is chosen automatically: small studies embed every table context
#' in the system prompt; larger studies embed a compact index and register
#' tools so the model can fetch details on demand. The switch-over point is
#' `ks_get_option("study_threshold")`.
#'
#' @param study A [ks_study] object.
#' @param model Character scalar. The model name for the chosen provider.
#' @param provider Character scalar. One of `"ollama"` (default),
#'   `"lm_studio"`, `"openai"`, `"anthropic"`. Defaults to
#'   `ks_get_option("provider")`.
#' @param base_url Optional character scalar. Override the provider base URL
#'   (e.g. a remote Ollama host).
#' @param echo Character scalar passed to the ellmer constructor controlling
#'   streaming output. Default `"none"`.
#' @param ... Additional arguments forwarded to the ellmer chat constructor.
#'
#' @return A `kschat` object wrapping the ellmer chat and the study.
#'
#' @examples
#' \dontrun{
#' study <- load_study("path/to/outputs/meta")
#' chat <- ks_chat(study, model = "qwen3:14b")
#' ask(chat, "Which populations are used across the efficacy tables?")
#' }
#'
#' @export
ks_chat <- function(study,
                    model,
                    provider = ks_get_option("provider"),
                    base_url = NULL,
                    echo = "none",
                    ...) {
  if (!is_ks_study(study)) {
    cli::cli_abort("{.arg study} must be a {.cls ks_study} object.")
  }
  checkmate::assert_string(model)
  checkmate::assert_string(provider)

  threshold <- ks_get_option("study_threshold")
  mode <- if (.study_n_outputs(study) <= threshold) "small" else "large"

  system_prompt <- .build_system_prompt(study, mode)
  ellmer_chat <- .make_ellmer_chat(provider, model, system_prompt, base_url, echo, ...)

  ks <- structure(
    list(chat = ellmer_chat, study = study, mode = mode, provider = provider),
    class = c("kschat", "list")
  )

  if (identical(mode, "large")) {
    .register_tools(ks)
  }

  ks
}

#' Test for a `kschat` Object
#'
#' @param x An object.
#' @return `TRUE` if `x` is a `kschat`, otherwise `FALSE`.
#' @export
is_kschat <- function(x) {
  inherits(x, "kschat")
}

#' @export
print.kschat <- function(x, ...) {
  cli::cli_h1("kschat")
  cli::cli_text("{.strong Provider}: {x$provider}   {.strong Mode}: {x$mode}")
  cli::cli_text(
    "{.strong Study}: {length(x$study$tables)} table{?s}, {length(x$study$figures)} figure{?s}"
  )
  if (identical(x$mode, "large")) {
    cli::cli_text("Tools registered for on-demand retrieval.")
  }
  invisible(x)
}
