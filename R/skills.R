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
  # system.md and study_index.md are infrastructure, not user-facing skills.
  builtin_names <- setdiff(builtin_names, c(.KS_SYSTEM_PROMPT, .KS_STUDY_INDEX_PROMPT))

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
#' - if `x` is a [ks_context], its JSON is used;
#' - if `x` is a [ks_study] and `id` is supplied, that table's JSON is used;
#' - if `x` is a [ks_study] without `id`, all table contexts are concatenated.
#'
#' Any additional named arguments in `...` (e.g. `audience`, `title`) fill the
#' matching placeholders in the template.
#'
#' @param x A [ks_study], [ks_context], or `kschat` object.
#' @param skill Character scalar. Skill name. Default `"describe"`.
#' @param id Optional character scalar. Table id when `x` is a study.
#' @param chat Optional `kschat`. Reuse an existing chat session; if `NULL`
#'   and `x` is a study/context, a temporary session is created.
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

  # Resolve the chat session and the study/context to describe.
  resolved <- .resolve_chat_and_context(x, chat, id)
  chat <- resolved$chat
  context_json <- resolved$context_json
  ctx_id <- resolved$id %||% (id %||% "")

  template <- .load_prompt(skill)
  prompt <- .fill_prompt(
    template,
    context = context_json,
    id = ctx_id,
    ...
  )

  chat$chat(prompt)
}

#' Resolve x + chat + id into a chat session and a context JSON string
#' @keywords internal
#' @noRd
.resolve_chat_and_context <- function(x, chat, id) {
  if (is_kschat(x)) {
    ks <- x
    study <- ks$study
    context_json <- if (!is.null(id)) {
      ctx <- study[[id]]
      if (is.null(ctx)) {
        cli::cli_abort("Output {.val {id}} not found in the study.")
      }
      as_json(ctx)
    } else {
      .concat_contexts(study$tables)
    }
    return(list(chat = ks$chat, context_json = context_json, id = id))
  }

  if (is_ks_context(x)) {
    if (is.null(chat)) {
      cli::cli_abort(c(
        "A chat session is required to run a skill on a bare {.cls ks_context}.",
        i = "Pass {.arg chat = ks_chat(study, model = ...)}."
      ))
    }
    return(list(chat = chat$chat, context_json = as_json(x), id = x$id))
  }

  if (is_ks_study(x)) {
    if (is.null(chat)) {
      cli::cli_abort(c(
        "A chat session is required to run a skill.",
        i = "Pass {.arg chat = ks_chat(study, model = ...)} or call {.fn ks_chat} first."
      ))
    }
    study <- x
    context_json <- if (!is.null(id)) {
      ctx <- study[[id]]
      if (is.null(ctx)) {
        cli::cli_abort("Output {.val {id}} not found in the study.")
      }
      as_json(ctx)
    } else {
      .concat_contexts(study$tables)
    }
    return(list(chat = chat$chat, context_json = context_json, id = id))
  }

  cli::cli_abort("{.arg x} must be a {.cls ks_study}, {.cls ks_context}, or {.cls kschat}.")
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
