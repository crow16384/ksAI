## Interactive API: the two thin conveniences that are not skill templates.
## Everything else goes through ks_llm(x, skill = ...).

#' Ask a Free-Form Question in a Chat Session
#'
#' Sends a question directly to an open [ks_chat()] session. The model answers
#' against whatever study context was wired in when the session was created
#' (all contexts in small-study mode, or the index plus tools in large-study
#' mode), and the conversation accumulates history for follow-ups.
#'
#' @param chat A `kschat` object from [ks_chat()].
#' @param question Character scalar. The question to ask.
#'
#' @return The model's text response (character scalar).
#'
#' @examples
#' \dontrun{
#' study <- load_study("path/to/outputs/meta")
#' chat <- ks_chat(study, model = "qwen3:14b")
#' ask(chat, "How do vital sign changes relate to the adverse event profile?")
#' ask(chat, "Which tables should I cite in the efficacy section?")
#' }
#'
#' @export
ask <- function(chat, question) {
  if (!is_kschat(chat)) {
    cli::cli_abort(c(
      "{.arg chat} must be a {.cls kschat} object.",
      i = "Create one with {.fn ks_chat}."
    ))
  }
  checkmate::assert_string(question)
  chat$chat$chat(question)
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
    context1 = as_json(a),
    context2 = as_json(b)
  )
  chat$chat$chat(prompt)
}
