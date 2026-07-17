## Reasoning agent: answer over retrieved capsules only.

#' Reason Over Retrieved Capsules
#'
#' Retrieves top capsules for a query and asks a reasoning model using only
#' those capsule summaries. Optionally expands context with child capsules.
#'
#' @param store A `ks_capsule_store`.
#' @param query User question.
#' @param n Number of top capsules to retrieve.
#' @param expand Logical. If `TRUE`, include child capsules of top results.
#' @param model Reasoning model name.
#' @param provider Provider (ollama/lm_studio/openai/anthropic).
#' @param base_url Optional provider URL override.
#' @param echo Echo mode forwarded to ellmer.
#' @param ... Extra args forwarded to chat constructor.
#'
#' @return A [ks_result].
#' @export
ks_reason <- function(store,
                      query,
                      n = 5L,
                      expand = FALSE,
                      model,
                      provider = ks_get_option("provider"),
                      base_url = NULL,
                      echo = "none",
                      ...) {
  if (!is_ks_capsule_store(store)) {
    cli::cli_abort("{.arg store} must be a {.cls ks_capsule_store} object.")
  }
  checkmate::assert_string(query)
  checkmate::assert_int(n, lower = 1L)
  checkmate::assert_flag(expand)
  checkmate::assert_string(model)
  dots <- rlang::list2(...)

  subset <- ks_retrieve(store, query = query, n = n)
  caps <- subset$capsules
  if (expand && length(caps)) {
    expanded <- caps
    for (cap in caps) {
      for (cid in cap$child_ids %||% character()) {
        if (cid %in% names(store$capsules)) {
          expanded[[cid]] <- store$capsules[[cid]]
        }
      }
    }
    caps <- expanded
  }
  context <- .reason_context_block(caps)
  system_prompt <- paste(
    "You are a clinical reasoning assistant.",
    "Use only the provided capsule facts and metadata.",
    "If evidence is missing, explicitly state that.",
    sep = " "
  )
  chat <- rlang::exec(
    .make_ellmer_chat,
    provider = provider,
    model = model,
    system_prompt = system_prompt,
    base_url = base_url,
    echo = echo,
    !!!dots
  )

  req <- paste(
    "Retrieved clinical capsules:",
    context,
    "User question:",
    query,
    sep = "\n\n"
  )
  response <- as.character(chat$chat(req))
  new_ks_result(
    ids = names(caps),
    skill = "reason",
    prompt = query,
    response = response,
    model = model,
    provider = provider
  )
}

#' @keywords internal
#' @noRd
.reason_context_block <- function(capsules) {
  if (!length(capsules)) return("_(No capsules retrieved.)_")
  blocks <- vapply(names(capsules), function(cid) {
    cap <- capsules[[cid]]
    paste(
      paste0("### Capsule ", cid),
      paste0("- domain: ", cap$domain),
      paste0("- level: ", cap$level),
      paste0("- label: ", cap$label),
      paste0("- source_id: ", cap$source_id),
      paste0("- parent_id: ", cap$parent_id %||% NA_character_),
      "",
      cap$compact_text %||% "",
      sep = "\n"
    )
  }, character(1))
  paste(blocks, collapse = "\n\n")
}
