## Skills: customizable, template-driven CSR-writing prompts.
##
## A "skill" is a Markdown prompt template with {{placeholder}} variables.
## Built-in skills ship in inst/prompts/. Users can override or add skills by
## pointing ks_set_option("skills_dir", <folder>) at a directory of .md files;
## a user skill shadows a built-in skill of the same name.

# ---------------------------------------------------------------------------
# Skill resolution
# ---------------------------------------------------------------------------

#' Resolve the file path of a skill prompt
#'
#' Checks the user skills directory first (if set via
#' `ks_set_option("skills_dir", ...)`), then the package's built-in prompts.
#'
#' @param name Character scalar. Skill name (without extension).
#' @return Character scalar path.
#' @keywords internal
#' @noRd
.resolve_skill_path <- function(name) {
  checkmate::assert_string(name)

  skills_dir <- ks_get_option("skills_dir")
  if (!is.null(skills_dir)) {
    user_path <- file.path(skills_dir, paste0(name, ".md"))
    if (file.exists(user_path)) {
      return(user_path)
    }
  }

  builtin <- system.file("prompts", paste0(name, ".md"), package = "ksAI")
  if (nzchar(builtin) && file.exists(builtin)) {
    return(builtin)
  }

  cli::cli_abort(c(
    "Skill {.val {name}} not found.",
    i = if (is.null(skills_dir)) {
      "Set {.code ks_set_option(skills_dir = ...)} to add custom skills."
    } else {
      "Looked in {.path {skills_dir}} and the package built-ins."
    }
  ))
}

#' Load a skill prompt template as a single string
#' @keywords internal
#' @noRd
.load_prompt <- function(name) {
  path <- .resolve_skill_path(name)
  paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
}

#' Fill `{{placeholders}}` in a template with named values
#'
#' @param template Character scalar. The template text.
#' @param ... Named substitutions, e.g. `context = "...", id = "14-3.01"`.
#' @return The filled template.
#' @keywords internal
#' @noRd
.fill_prompt <- function(template, ...) {
  subs <- rlang::list2(...)
  if (length(subs) == 0) {
    return(template)
  }
  if (is.null(names(subs)) || any(names(subs) == "")) {
    cli::cli_abort("All substitutions passed to {.fn .fill_prompt} must be named.")
  }
  for (key in names(subs)) {
    value <- paste(as.character(subs[[key]]), collapse = "\n")
    template <- gsub(paste0("{{", key, "}}"), value, template, fixed = TRUE)
  }
  template
}

# ---------------------------------------------------------------------------
# Skill discovery
# ---------------------------------------------------------------------------

#' List Available Skills
#'
#' Returns the CSR-writing skills available to [ks_llm()], combining the
#' package built-ins with any user skills in `ks_get_option("skills_dir")`.
#' User skills shadow built-ins of the same name.
#'
#' @return A data frame with columns `name`, `source` (`"user"` or
#'   `"built-in"`), and `path`.
#'
#' @examples
#' ks_list_skills()
#'
#' @export
ks_list_skills <- function() {
  builtin_dir <- system.file("prompts", package = "ksAI")
  builtin_files <- if (nzchar(builtin_dir)) {
    list.files(builtin_dir, pattern = "\\.md$", full.names = FALSE)
  } else {
    character()
  }
  builtin_names <- sub("\\.md$", "", builtin_files)
  # system.md, system_single.md and study_index.md are infrastructure, not
  # user-facing skills.
  builtin_names <- setdiff(
    builtin_names,
    c(.KS_SYSTEM_PROMPT, .KS_SINGLE_SYSTEM_PROMPT, .KS_STUDY_INDEX_PROMPT)
  )

  df <- data.frame(
    name = builtin_names,
    source = rep("built-in", length(builtin_names)),
    path = file.path(builtin_dir, paste0(builtin_names, ".md")),
    stringsAsFactors = FALSE
  )

  skills_dir <- ks_get_option("skills_dir")
  if (!is.null(skills_dir) && dir.exists(skills_dir)) {
    user_files <- list.files(skills_dir, pattern = "\\.md$", full.names = FALSE)
    user_names <- sub("\\.md$", "", user_files)
    if (length(user_names)) {
      user_df <- data.frame(
        name = user_names,
        source = rep("user", length(user_names)),
        path = file.path(skills_dir, paste0(user_names, ".md")),
        stringsAsFactors = FALSE
      )
      # User skills shadow built-ins of the same name.
      df <- df[!df$name %in% user_df$name, , drop = FALSE]
      df <- rbind(user_df, df)
    }
  }

  df <- df[order(df$name), , drop = FALSE]
  rownames(df) <- NULL
  df
}

# ---------------------------------------------------------------------------
# Dispatch
# ---------------------------------------------------------------------------

#' Run a CSR-Writing Skill Against a Study or Table
#'
#' Loads a skill prompt template, fills its `{{placeholders}}` from the given
#' context, and sends it to the LLM. Skills are Markdown templates; built-ins
#' include `"describe"`, `"summarize"`, `"csr_section"`, and `"review"`. Add
#' your own by pointing `ks_set_option("skills_dir", ...)` at a folder of
#' `.md` files.
#'
#' The `{{context}}` placeholder is filled automatically from `x`:
#'
#' - a single output (a [ks_context], or a [ks_study]/`kschat` with `id`) is
#'   rendered as a human-readable Markdown table and run on a *focused* chat,
#'   so the model sees only that output and is not flooded with the whole
#'   study;
#' - a [ks_study]/`kschat` without `id` concatenates all table contexts as
#'   JSON and reuses the existing chat session.
#'
#' Any additional named arguments in `...` (e.g. `audience`, `title`) fill the
#' matching placeholders in the template.
#'
#' @param x A [ks_study], [ks_context], or `kschat` object.
#' @param skill Character scalar. Skill name. Default `"describe"`.
#' @param id Optional character scalar. Table id when `x` is a study.
#' @param chat Optional `kschat`. Supplies the connection settings; required
#'   when `x` is a [ks_study] or bare [ks_context].
#' @param ... Named values filling additional template placeholders.
#'
#' @return The LLM's text response (character scalar).
#'
#' @examples
#' \dontrun{
#' study <- load_study("path/to/outputs/meta")
#' ks_llm(study, skill = "describe", id = "14-3.01")
#' ks_llm(study, skill = "summarize", id = "14-3.01", audience = "clinician")
#' ks_llm(study, skill = "csr_section", id = "14-3.01", title = "ADAS-Cog")
#' }
#'
#' @export
ks_llm <- function(x, skill = "describe", id = NULL, chat = NULL, ...) {
  checkmate::assert_string(skill)

  # Resolve the chat session and the context to run the skill against.
  resolved <- .resolve_chat_and_context(x, chat, id)

  template <- .load_prompt(skill)
  prompt <- .assemble_skill_prompt(template, context = resolved$context, id = resolved$id, ...)

  resolved$chat$chat(prompt)
}

#' Fill a skill template with its context, id, and extra placeholders
#'
#' Split out from [ks_llm()] so the assembled prompt can be inspected in tests
#' without contacting a model.
#' @keywords internal
#' @noRd
.assemble_skill_prompt <- function(template, context, id, ...) {
  .fill_prompt(
    template,
    context = context,
    id = id %||% "",
    ...
  )
}

#' Resolve x + chat + id into a chat session and a context string
#'
#' Single-output targeting (an `id`, or a bare [ks_context]) renders the target
#' as human-readable Markdown and runs it on a *focused* chat: a fresh session
#' whose system prompt carries only the constraints, so the model is never
#' flooded with the whole study nor sent the target table twice. Study-wide
#' calls (no `id`) reuse the existing session and its full JSON contexts.
#' @keywords internal
#' @noRd
.resolve_chat_and_context <- function(x, chat, id) {
  if (is_kschat(x)) {
    return(.resolve_from_kschat(x, id))
  }

  if (is_ks_context(x)) {
    if (is.null(chat)) {
      cli::cli_abort(c(
        "A chat session is required to run a skill on a bare {.cls ks_context}.",
        i = "Pass {.arg chat = ks_chat(study, model = ...)}."
      ))
    }
    if (!is_kschat(chat)) {
      cli::cli_abort("{.arg chat} must be a {.cls kschat} object.")
    }
    return(list(chat = .make_focused_chat(chat), context = as_markdown(x), id = x$id))
  }

  if (is_ks_study(x)) {
    if (is.null(chat) || !is_kschat(chat)) {
      cli::cli_abort(c(
        "A chat session is required to run a skill.",
        i = "Pass {.arg chat = ks_chat(study, model = ...)} or call {.fn ks_chat} first."
      ))
    }
    return(.resolve_from_kschat(chat, id, study = x))
  }

  cli::cli_abort("{.arg x} must be a {.cls ks_study}, {.cls ks_context}, or {.cls kschat}.")
}

#' Resolve a chat + context from a `kschat` (and optional overriding study)
#' @keywords internal
#' @noRd
.resolve_from_kschat <- function(ks, id, study = ks$study) {
  if (!is.null(id)) {
    ctx <- study[[id]]
    if (is.null(ctx)) {
      cli::cli_abort("Output {.val {id}} not found in the study.")
    }
    return(list(chat = .make_focused_chat(ks), context = as_markdown(ctx), id = id))
  }
  # Study-wide: reuse the existing session and the full JSON contexts.
  list(chat = ks$chat, context = .concat_contexts(study$tables), id = NULL)
}

#' Concatenate multiple contexts into one JSON-array-ish string
#' @keywords internal
#' @noRd
.concat_contexts <- function(contexts) {
  if (length(contexts) == 0) {
    return("[]")
  }
  parts <- vapply(contexts, as_json, character(1))
  paste0("[\n", paste(parts, collapse = ",\n"), "\n]")
}
