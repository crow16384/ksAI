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
  # system*.md and capsule_*.md are infrastructure prompts, not CSR skills.
  builtin_names <- setdiff(
    builtin_names,
    c(.KS_SYSTEM_PROMPT, "system_single", "capsule_classify", "capsule_review")
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
# Prompt assembly helpers
# ---------------------------------------------------------------------------

#' Resolve study + chat connection from ks_study/kschat input
#' @keywords internal
#' @noRd
.resolve_chat_session <- function(x,
                                  model,
                                  provider,
                                  base_url,
                                  echo) {
  if (is_kschat(x)) {
    return(list(
      chat = x$chat,
      study = x$study,
      model = x$model,
      provider = x$provider
    ))
  }

  if (!is_ks_study(x)) {
    cli::cli_abort("{.arg x} must be a {.cls ks_study} or {.cls kschat} object.")
  }

  if (is.null(model)) {
    cli::cli_abort(c(
      "{.arg model} is required when {.arg x} is a {.cls ks_study}.",
      i = "Pass {.code model = ...} or provide a {.cls kschat} object."
    ))
  }

  resolved_provider <- provider %||% ks_get_option("provider")
  chat <- .make_ellmer_chat(
    provider = resolved_provider,
    model = model,
    system_prompt = .build_single_system_prompt(),
    base_url = base_url,
    echo = echo
  )

  list(chat = chat, study = x, model = model, provider = resolved_provider)
}

#' Resolve and validate requested IDs against a study
#' @keywords internal
#' @noRd
.resolve_contexts_by_ids <- function(study, ids) {
  checkmate::assert_character(ids, min.len = 1, any.missing = FALSE, unique = TRUE)

  contexts <- lapply(ids, function(id) study[[id]])
  names(contexts) <- ids
  missing <- ids[vapply(contexts, is.null, logical(1))]
  if (length(missing) > 0) {
    cli::cli_abort(c(
      "Some requested outputs were not found in the loaded study.",
      x = "Missing id{?s}: {.val {missing}}"
    ))
  }
  contexts
}

#' Render one or more output contexts in the chosen format
#' @keywords internal
#' @noRd
.render_contexts <- function(contexts, format = "markdown") {
  if (length(contexts) == 0) {
    return("_(No context loaded.)_")
  }
  format <- match.arg(format, c("markdown", "compact", "json"))
  renderer <- switch(
    format,
    markdown = as_markdown,
    compact = as_compact,
    json = as_json
  )
  blocks <- vapply(names(contexts), function(id) {
    body <- renderer(contexts[[id]])
    if (identical(format, "compact")) {
      paste0("---\n\n", body)
    } else {
      paste0("### Output ", id, "\n\n", body)
    }
  }, character(1))
  paste(blocks, collapse = "\n\n")
}

#' Render a single context with the chosen format
#' @keywords internal
#' @noRd
.render_one_context <- function(ctx, format = "markdown") {
  format <- match.arg(format, c("markdown", "compact", "json"))
  switch(
    format,
    markdown = as_markdown(ctx),
    compact = as_compact(ctx),
    json = as_json(ctx)
  )
}

#' Build final request text from base prompt + optional prior + user prompt
#' @keywords internal
#' @noRd
.compose_request <- function(base_prompt, prompt = NULL, prior = NULL) {
  out <- base_prompt

  if (!is.null(prompt) && nzchar(prompt)) {
    out <- paste0(out, "\n\nAdditional user request:\n", prompt)
  }

  if (!is.null(prior)) {
    out <- paste0(
      "Prior analysis:\n\n",
      prior$response,
      "\n\n---\n\n",
      out
    )
  }

  out
}

# ---------------------------------------------------------------------------
# Dispatch
# ---------------------------------------------------------------------------

#' Run a Skill or Free Prompt Against Selected Outputs
#'
#' Runs one of the registered skill templates (or a free prompt) against one or
#' more loaded output ids. Returns a [ks_result] that can be saved via
#' [save_result()] and loaded later via [load_result()].
#'
#' @param x A [ks_study] or `kschat` object.
#' @param ids Character vector of output ids to include as context.
#' @param skill Optional skill name. Defaults to `"describe"`.
#' @param prompt Optional free-form user instructions. If `skill` is `NULL`,
#'   this is the main prompt body.
#' @param prior Optional [ks_result] from a previous run. Its response is
#'   prepended as prior analysis context.
#' @param model Optional model name when `x` is a [ks_study]. Ignored for
#'   `kschat` input.
#' @param provider Optional provider when `x` is a [ks_study]. Ignored for
#'   `kschat` input.
#' @param base_url Optional provider URL override when `x` is a [ks_study].
#' @param echo Echo mode forwarded to ellmer when `x` is a [ks_study].
#' @param context_format Context serialization format: `"markdown"` (default),
#'   `"compact"`, or `"json"`. Defaults to the `"context_format"` package option.
#' @param ... Named placeholders for the selected skill template.
#'
#' @return A [ks_result] object.
#'
#' @examples
#' \dontrun{
#' study <- ks_load("path/to/outputs/meta", ids = c("14-3.01", "14-3.02"))
#' out <- ks_llm(study, ids = "14-3.01", skill = "describe", model = "qwen3:14b")
#' out2 <- ks_llm(study, ids = c("14-3.01", "14-3.02"), prompt = "Compare trends")
#' }
#'
#' @export
ks_llm <- function(x,
                   ids,
                   skill = "describe",
                   prompt = NULL,
                   prior = NULL,
                   model = NULL,
                   provider = ks_get_option("provider"),
                   base_url = NULL,
                   echo = "none",
                   context_format = ks_get_option("context_format"),
                   ...) {
  checkmate::assert_character(ids, min.len = 1, any.missing = FALSE, unique = TRUE)
  checkmate::assert_string(skill, null.ok = TRUE)
  checkmate::assert_string(prompt, null.ok = TRUE)
  context_format <- match.arg(context_format, c("markdown", "compact", "json"))
  if (!is.null(prior) && !is_ks_result(prior)) {
    cli::cli_abort("{.arg prior} must be a {.cls ks_result} object.")
  }
  if (is.null(skill) && is.null(prompt)) {
    cli::cli_abort("Provide at least one of {.arg skill} or {.arg prompt}.")
  }

  dots <- rlang::list2(...)
  if (length(dots) && (is.null(names(dots)) || any(names(dots) == ""))) {
    cli::cli_abort("All extra substitutions passed to {.fn ks_llm} must be named.")
  }

  session <- .resolve_chat_session(
    x = x,
    model = model,
    provider = provider,
    base_url = base_url,
    echo = echo
  )
  contexts <- .resolve_contexts_by_ids(session$study, ids)

  if (!is.null(skill) && identical(skill, "describe")) {
    template <- .load_prompt(skill)
    chunks <- lapply(ids, function(id) {
      base_prompt <- .fill_prompt(
        template,
        id = id,
        ids = paste(ids, collapse = ", "),
        context = .render_one_context(contexts[[id]], context_format),
        !!!dots
      )
      req <- .compose_request(base_prompt, prompt = prompt, prior = prior)
      text <- as.character(session$chat$chat(req))
      paste0("## ", id, "\n\n", text)
    })
    response <- paste(unlist(chunks, use.names = FALSE), collapse = "\n\n")
  } else if (!is.null(skill) && identical(skill, "review")) {
    if (length(ids) != 2L) {
      cli::cli_abort("Skill {.val review} requires exactly two IDs.")
    }
    template <- .load_prompt(skill)
    base_prompt <- .fill_prompt(
      template,
      id = paste(ids, collapse = ", "),
      ids = paste(ids, collapse = ", "),
      id1 = ids[[1]],
      id2 = ids[[2]],
      context = .render_contexts(contexts, context_format),
      context1 = .render_one_context(contexts[[1]], context_format),
      context2 = .render_one_context(contexts[[2]], context_format),
      !!!dots
    )
    req <- .compose_request(base_prompt, prompt = prompt, prior = prior)
    response <- as.character(session$chat$chat(req))
  } else if (!is.null(skill)) {
    template <- .load_prompt(skill)
    context_block <- if (length(ids) == 1L) {
      .render_one_context(contexts[[1]], context_format)
    } else {
      .render_contexts(contexts, context_format)
    }
    id_value <- if (length(ids) == 1L) ids[[1]] else paste(ids, collapse = ", ")
    base_prompt <- .fill_prompt(
      template,
      id = id_value,
      ids = paste(ids, collapse = ", "),
      context = context_block,
      !!!dots
    )
    req <- .compose_request(base_prompt, prompt = prompt, prior = prior)
    response <- as.character(session$chat$chat(req))
  } else {
    context_block <- if (length(ids) == 1L) {
      .render_one_context(contexts[[1]], context_format)
    } else {
      .render_contexts(contexts, context_format)
    }
    base_prompt <- paste0(
      "Use the following output context",
      if (length(ids) > 1L) "s" else "",
      ":\n\n",
      context_block,
      "\n\nUser request:\n",
      prompt
    )
    req <- .compose_request(base_prompt, prompt = NULL, prior = prior)
    response <- as.character(session$chat$chat(req))
  }

  new_ks_result(
    ids = ids,
    skill = skill,
    prompt = prompt,
    response = response,
    model = session$model,
    provider = session$provider
  )
}
