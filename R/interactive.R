## Interactive API: the two thin conveniences that are not skill templates.
## Everything else goes through ks_llm(x, skill = ...).

#' Ask a Free-Form Question in a Chat Session
#'
#' Sends a question directly to an open [ks_chat()] session. The model answers
#' against whatever study context was wired in when the session was created
#' (all contexts in small-study mode, or the index plus tools in large-study
#' mode), and the conversation accumulates history for follow-ups.
#'
#' Supplying `id` spotlights a single output: the target table is rendered
#' inline (as Markdown) and the model is asked to focus on it *while still
#' taking the rest of the study into account*. This differs from
#' [ks_llm()] with an `id`, which answers about that output in isolation.
#'
#' @param chat A `kschat` object from [ks_chat()].
#' @param question Character scalar. The question to ask.
#' @param id Optional character scalar. An output id to spotlight while keeping
#'   the whole-study context available.
#'
#' @return The model's text response (character scalar).
#'
#' @examples
#' \dontrun{
#' study <- load_study("path/to/outputs/meta")
#' chat <- ks_chat(study, model = "qwen3:14b")
#' ask(chat, "How do vital sign changes relate to the adverse event profile?")
#' # Focus on one table, but reason across the whole study:
#' ask(chat, "Is this table consistent with the safety narrative?", id = "14-3.01")
#' }
#'
#' @export
ask <- function(chat, question, id = NULL) {
  if (!is_kschat(chat)) {
    cli::cli_abort(c(
      "{.arg chat} must be a {.cls kschat} object.",
      i = "Create one with {.fn ks_chat}."
    ))
  }
  checkmate::assert_string(question)
  checkmate::assert_string(id, null.ok = TRUE)

  if (is.null(id)) {
    return(chat$chat$chat(question))
  }

  ctx <- chat$study[[id]]
  if (is.null(ctx)) {
    cli::cli_abort("Output {.val {id}} not found in the study.")
  }
  # Spotlight the single output inline, but keep the whole-study session (its
  # system prompt already carries the other contexts / index + tools).
  prompt <- paste0(
    "Focus on output ", id, ", shown below, while taking the rest of the ",
    "study into account where relevant.\n\n",
    as_markdown(ctx),
    "\n\nQuestion: ", question
  )
  chat$chat$chat(prompt)
}

#' Compare Two Study Outputs with LLM Narration
#'
#' Runs the `"review"` skill over two outputs, producing a narrated,
#' consistency-focused comparison. This is a convenience wrapper around
#' [ks_llm()] for the common two-table case.
#'
#' @param chat A `kschat` object from [ks_chat()].
#' @param id1 Character scalar. First output id.
#' @param id2 Character scalar. Second output id.
#'
#' @return The model's text response (character scalar).
#'
#' @examples
#' \dontrun{
#' compare_tables(chat, "14-3.01", "14-3.02")
#' }
#'
#' @export
compare_tables <- function(chat, id1, id2) {
  if (!is_kschat(chat)) {
    cli::cli_abort(c(
      "{.arg chat} must be a {.cls kschat} object.",
      i = "Create one with {.fn ks_chat}."
    ))
  }
  checkmate::assert_string(id1)
  checkmate::assert_string(id2)

  study <- chat$study
  a <- study[[id1]]
  b <- study[[id2]]
  if (is.null(a)) cli::cli_abort("Output {.val {id1}} not found in the study.")
  if (is.null(b)) cli::cli_abort("Output {.val {id2}} not found in the study.")

  template <- .load_prompt("review")
  prompt <- .fill_prompt(
    template,
    id1 = id1,
    id2 = id2,
    context1 = as_markdown(a),
    context2 = as_markdown(b)
  )
  .make_focused_chat(chat)$chat(prompt)
}
