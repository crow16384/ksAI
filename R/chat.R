## ks_chat: wrap an ellmer Chat around a targeted subset of study outputs.

# ---------------------------------------------------------------------------
# Prompt builders
# ---------------------------------------------------------------------------

#' Render all loaded outputs as one Markdown context block
#' @keywords internal
#' @noRd
.study_context_markdown <- function(study) {
  all <- .study_all(study)
  if (length(all) == 0) {
    return("_(No outputs loaded.)_")
  }
  blocks <- vapply(all, function(ctx) {
    paste0("### Output ", ctx$id, "\n\n", as_markdown(ctx))
  }, character(1))
  paste(blocks, collapse = "\n\n")
}

#' Build the system prompt for a targeted study session
#' @keywords internal
#' @noRd
.build_system_prompt <- function(study) {
  base <- .load_prompt(.KS_SYSTEM_PROMPT)
  study_context <- paste0(
    "## Loaded output contexts\n\n",
    .study_context_markdown(study)
  )
  .fill_prompt(base, study_context = study_context)
}

#' Build the focused system prompt for skill calls
#' @keywords internal
#' @noRd
.build_single_system_prompt <- function() {
  .load_prompt("system_single")
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

#' Open an AI Chat Session Over Loaded Outputs
#'
#' Creates an [ellmer][ellmer::ellmer] chat wired to the currently loaded
#' [ks_study] subset.
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
#' @return A `kschat` object wrapping the ellmer chat and the loaded study.
#'
#' @examples
#' \dontrun{
#' study <- ks_load("path/to/outputs/meta", ids = c("14-3.01"))
#' chat <- ks_chat(study, model = "qwen3:14b")
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

  system_prompt <- .build_system_prompt(study)
  ellmer_chat <- .make_ellmer_chat(provider, model, system_prompt, base_url, echo, ...)

  structure(
    list(
      chat = ellmer_chat,
      study = study,
      mode = "targeted",
      provider = provider,
      model = model,
      base_url = base_url,
      echo = echo,
      dots = list(...)
    ),
    class = c("kschat", "list")
  )
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
    "{.strong Study}: {length(x$study$tables)} table{?s}, {length(x$study$figures)} figure{?s}, {length(x$study$texts)} text{?s}"
  )
  invisible(x)
}
