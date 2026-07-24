## Clinical capsules: LLM-formed semantic groups over tables and figures.

# ---------------------------------------------------------------------------
# Constructors / predicates
# ---------------------------------------------------------------------------

#' @keywords internal
#' @noRd
new_ks_capsule <- function(capsule_id,
                           label = "",
                           member_ids = character(),
                           parent_id = NA_character_,
                           child_ids = character(),
                           population = NA_character_,
                           compact_text = "",
                           concepts = character(),
                           keywords = character(),
                           embedding = NULL,
                           synonyms = character(),
                           confidence = NA_real_) {
  structure(
    list(
      capsule_id = as.character(capsule_id),
      label = as.character(label),
      member_ids = as.character(member_ids %||% character()),
      parent_id = as.character(parent_id %||% NA_character_),
      child_ids = as.character(child_ids %||% character()),
      population = as.character(population %||% NA_character_),
      compact_text = as.character(compact_text %||% ""),
      concepts = as.character(concepts %||% character()),
      keywords = as.character(keywords %||% character()),
      embedding = embedding,
      synonyms = as.character(synonyms %||% character()),
      confidence = suppressWarnings(as.numeric(confidence %||% NA_real_))
    ),
    class = c("ks_capsule", "list")
  )
}

#' @keywords internal
#' @noRd
new_ks_capsule_store <- function(capsules = list(),
                                 study_id = NULL,
                                 meta_dir = NULL,
                                 built_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")) {
  structure(
    list(
      capsules = capsules,
      study_id = study_id,
      meta_dir = meta_dir,
      built_at = built_at
    ),
    class = c("ks_capsule_store", "list")
  )
}

#' The `ks_capsule` Class
#'
#' A `ks_capsule` is a named semantic unit grouping one or more table/figure
#' outputs (`member_ids`) produced by [as_capsules()]. Capsules form a tree via
#' `parent_id` / `child_ids` and store compact text plus optional embeddings.
#'
#' @param x An object.
#' @return `TRUE` if `x` is a `ks_capsule`, otherwise `FALSE`.
#' @name ks_capsule
#' @aliases is_ks_capsule
#' @export
is_ks_capsule <- function(x) {
  inherits(x, "ks_capsule")
}

#' The `ks_capsule_store` Class
#'
#' A `ks_capsule_store` is a named registry of capsules produced by
#' [as_capsules()], with study-level metadata for persistence and retrieval.
#'
#' @param x An object.
#' @return `TRUE` if `x` is a `ks_capsule_store`, otherwise `FALSE`.
#' @name ks_capsule_store
#' @aliases is_ks_capsule_store
#' @export
is_ks_capsule_store <- function(x) {
  inherits(x, "ks_capsule_store")
}

#' @export
print.ks_capsule <- function(x, ...) {
  cli::cli_h1("ks_capsule: {x$capsule_id}")
  cli::cli_text("{.strong Label}: {x$label}")
  cli::cli_text("{.strong Members}: {paste(x$member_ids, collapse = ', ')}")
  cli::cli_text("{.strong Parent}: {x$parent_id %||% NA_character_}")
  cli::cli_text("{.strong Children}: {length(x$child_ids)}")
  cli::cli_text("{.strong Keywords}: {length(x$keywords)}")
  if (!is.null(x$embedding)) {
    cli::cli_text("{.strong Embedding dims}: {length(x$embedding)}")
  }
  invisible(x)
}

#' @export
print.ks_capsule_store <- function(x, ...) {
  cli::cli_h1("ks_capsule_store")
  cli::cli_text("{.strong Capsules}: {length(x$capsules)}")
  if (!is.null(x$study_id) && nzchar(x$study_id)) {
    cli::cli_text("{.strong Study}: {x$study_id}")
  }
  if (!is.null(x$meta_dir) && nzchar(x$meta_dir)) {
    cli::cli_text("{.strong Meta dir}: {.path {x$meta_dir}}")
  }
  cli::cli_text("{.strong Built at}: {x$built_at}")
  invisible(x)
}

# ---------------------------------------------------------------------------
# as_capsules — LLM-only formation
# ---------------------------------------------------------------------------

#' Build Clinical Capsules from Contexts (LLM)
#'
#' Groups **tables** and **figures** into a named semantic capsule tree using
#' an LLM only (small or large). There is no rule-based / CDISC formation path.
#' `model` is required. Figure image pixels are attached for vision-capable
#' models; R does not interpret plots.
#'
#' @param x A `ks_context` or `ks_study`.
#' @param model LLM model name (required).
#' @param provider LLM provider. Defaults to [ks_get_option()]`"provider"`.
#' @param base_url Optional provider URL override.
#' @param max_excerpt_rows Maximum table rows included in each catalog excerpt.
#' @param detail `"compact"` (default) or `"full"` table excerpts.
#' @param min_confidence Minimum confidence (0–1) to keep an LLM capsule.
#' @param batch_size Maximum catalog items per classify call before an LLM
#'   merge pass.
#' @param attach_images Logical. Attach figure assets via ellmer when readable.
#' @param ... Extra args forwarded to the ellmer chat constructor.
#'
#' @return A `ks_capsule_store`.
#' @export
as_capsules <- function(x,
                        model,
                        provider = ks_get_option("provider"),
                        base_url = NULL,
                        max_excerpt_rows = 12L,
                        detail = c("compact", "full"),
                        min_confidence = 0.5,
                        batch_size = 24L,
                        attach_images = TRUE,
                        ...) {
  UseMethod("as_capsules")
}

#' @rdname as_capsules
#' @export
as_capsules.ks_context <- function(x,
                                   model,
                                   provider = ks_get_option("provider"),
                                   base_url = NULL,
                                   max_excerpt_rows = 12L,
                                   detail = c("compact", "full"),
                                   min_confidence = 0.5,
                                   batch_size = 24L,
                                   attach_images = TRUE,
                                   ...) {
  if (!identical(as.character(x$type %||% ""), "Text")) {
    ctxs <- list(x)
    names(ctxs) <- x$id
    study <- new_ks_study(ctxs, meta_dir = NULL)
  } else {
    cli::cli_abort("{.fn as_capsules} accepts Table/Figure contexts, not Text.")
  }
  as_capsules.ks_study(
    study,
    model = model,
    provider = provider,
    base_url = base_url,
    max_excerpt_rows = max_excerpt_rows,
    detail = detail,
    min_confidence = min_confidence,
    batch_size = batch_size,
    attach_images = attach_images,
    ...
  )
}

#' @rdname as_capsules
#' @export
as_capsules.ks_study <- function(x,
                                 model,
                                 provider = ks_get_option("provider"),
                                 base_url = NULL,
                                 max_excerpt_rows = 12L,
                                 detail = c("compact", "full"),
                                 min_confidence = 0.5,
                                 batch_size = 24L,
                                 attach_images = TRUE,
                                 ...) {
  checkmate::assert_string(model, min.chars = 1L)
  checkmate::assert_int(max_excerpt_rows, lower = 1L)
  checkmate::assert_number(min_confidence, lower = 0, upper = 1)
  checkmate::assert_int(batch_size, lower = 1L)
  checkmate::assert_flag(attach_images)
  detail <- match.arg(detail)
  dots <- rlang::list2(...)

  catalog <- .capsule_catalog_contexts(x)
  if (!length(catalog)) {
    return(new_ks_capsule_store(
      capsules = list(),
      study_id = if (!is.null(x$meta_dir)) basename(x$meta_dir) else NULL,
      meta_dir = x$meta_dir
    ))
  }

  chat <- .make_capsule_classify_chat(
    model = model,
    provider = provider,
    base_url = base_url,
    dots = dots
  )

  ids <- names(catalog)
  chunks <- split(ids, ceiling(seq_along(ids) / batch_size))
  partials <- lapply(chunks, function(chunk_ids) {
    .capsule_classify_chunk(
      chat = chat,
      catalog = catalog[chunk_ids],
      max_excerpt_rows = max_excerpt_rows,
      detail = detail,
      attach_images = attach_images
    )
  })

  raw_caps <- if (length(partials) == 1L) {
    partials[[1]]
  } else {
    .capsule_llm_merge(
      chat = chat,
      partials = partials,
      catalog_ids = ids
    )
  }

  capsules <- .capsule_validate_and_build(
    raw_caps = raw_caps,
    catalog = catalog,
    min_confidence = min_confidence,
    max_excerpt_rows = max_excerpt_rows,
    detail = detail
  )

  new_ks_capsule_store(
    capsules = capsules,
    study_id = if (!is.null(x$meta_dir)) basename(x$meta_dir) else NULL,
    meta_dir = x$meta_dir
  )
}

# ---------------------------------------------------------------------------
# Persistence
# ---------------------------------------------------------------------------

#' Save a Capsule Store to a `.ksc` File
#'
#' @param store A `ks_capsule_store`.
#' @param path Output path (`.ksc` appended if missing).
#' @return The path written, invisibly.
#' @export
save_capsules <- function(store, path) {
  if (!is_ks_capsule_store(store)) {
    cli::cli_abort("{.arg store} must be a {.cls ks_capsule_store} object.")
  }
  checkmate::assert_string(path)
  if (!grepl("\\.ksc$", path)) {
    path <- paste0(path, ".ksc")
  }
  payload <- list(
    study_id = store$study_id,
    meta_dir = store$meta_dir,
    built_at = store$built_at,
    capsules = lapply(store$capsules, unclass)
  )
  writeLines(
    jsonlite::toJSON(payload, auto_unbox = TRUE, null = "null", digits = NA),
    con = path
  )
  invisible(path)
}

#' Load a Capsule Store from a `.ksc` File
#'
#' @param path Path to a `.ksc` file.
#' @return A `ks_capsule_store`.
#' @export
load_capsules <- function(path) {
  checkmate::assert_string(path)
  if (!file.exists(path)) {
    cli::cli_abort("Capsule file not found: {.path {path}}.")
  }
  payload <- tryCatch(
    jsonlite::fromJSON(path, simplifyVector = FALSE),
    error = function(e) NULL
  )
  if (is.null(payload)) {
    cli::cli_abort("Could not parse capsule file {.path {path}}.")
  }
  capsules <- payload$capsules %||% list()
  capsules <- lapply(capsules, function(c) {
    # Backward-compatible load: prefer member_ids; fall back to source_id.
    member_ids <- as.character(unlist(c$member_ids) %||% character())
    if (!length(member_ids) && !is.null(c$source_id) && nzchar(as.character(c$source_id))) {
      member_ids <- as.character(c$source_id)
    }
    new_ks_capsule(
      capsule_id = c$capsule_id %||% "",
      label = c$label %||% "",
      member_ids = member_ids,
      parent_id = c$parent_id %||% NA_character_,
      child_ids = as.character(unlist(c$child_ids) %||% character()),
      population = c$population %||% NA_character_,
      compact_text = c$compact_text %||% "",
      concepts = as.character(unlist(c$concepts) %||% character()),
      keywords = as.character(unlist(c$keywords) %||% character()),
      embedding = if (is.null(c$embedding)) NULL else as.numeric(unlist(c$embedding)),
      synonyms = as.character(unlist(c$synonyms) %||% character()),
      confidence = c$confidence %||% NA_real_
    )
  })
  names(capsules) <- vapply(capsules, function(c) c$capsule_id, character(1))
  new_ks_capsule_store(
    capsules = capsules,
    study_id = payload$study_id %||% NULL,
    meta_dir = payload$meta_dir %||% NULL,
    built_at = payload$built_at %||% format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  )
}

# ---------------------------------------------------------------------------
# Review APIs (inspect LLM-built stores; not formation)
# ---------------------------------------------------------------------------

#' Capsule Tree as Nested List / Printable Structure
#'
#' @param store A `ks_capsule_store`.
#' @param print Logical. If `TRUE`, print a tree to the console.
#' @return Invisibly, a named list of tree nodes.
#' @export
capsule_tree <- function(store, print = TRUE) {
  if (!is_ks_capsule_store(store)) {
    cli::cli_abort("{.arg store} must be a {.cls ks_capsule_store} object.")
  }
  checkmate::assert_flag(print)
  caps <- store$capsules
  if (!length(caps)) {
    if (print) cli::cli_text("(empty capsule store)")
    return(invisible(list()))
  }
  roots <- names(Filter(
    function(c) is.na(c$parent_id) || !nzchar(c$parent_id) ||
      !(c$parent_id %in% names(caps)),
    caps
  ))
  walk <- function(cid, depth = 0L) {
    cap <- caps[[cid]]
    node <- list(
      capsule_id = cid,
      label = cap$label,
      n_members = length(cap$member_ids),
      children = lapply(cap$child_ids, walk, depth = depth + 1L)
    )
    if (print) {
      pad <- paste(rep("  ", depth), collapse = "")
      cli::cli_text("{pad}{.strong {cid}} — {cap$label} ({length(cap$member_ids)} member{?s})")
    }
    node
  }
  tree <- lapply(roots, walk)
  names(tree) <- roots
  invisible(tree)
}

#' Capsule Membership Table
#'
#' @param store A `ks_capsule_store`.
#' @param study Optional `ks_study` to include catalog ids with zero membership.
#' @return A data.frame with columns `output_id`, `capsule_id`, `label`, `n_capsules`.
#' @export
capsule_membership <- function(store, study = NULL) {
  if (!is_ks_capsule_store(store)) {
    cli::cli_abort("{.arg store} must be a {.cls ks_capsule_store} object.")
  }
  rows <- list()
  for (cid in names(store$capsules)) {
    cap <- store$capsules[[cid]]
    for (mid in cap$member_ids) {
      rows[[length(rows) + 1L]] <- data.frame(
        output_id = mid,
        capsule_id = cid,
        label = cap$label,
        stringsAsFactors = FALSE
      )
    }
  }
  df <- if (length(rows)) {
    do.call(rbind, rows)
  } else {
    data.frame(
      output_id = character(),
      capsule_id = character(),
      label = character(),
      stringsAsFactors = FALSE
    )
  }
  if (!is.null(study)) {
    if (!is_ks_study(study)) {
      cli::cli_abort("{.arg study} must be a {.cls ks_study} object.")
    }
    catalog_ids <- names(.capsule_catalog_contexts(study))
    missing <- setdiff(catalog_ids, unique(df$output_id))
    if (length(missing)) {
      df <- rbind(
        df,
        data.frame(
          output_id = missing,
          capsule_id = NA_character_,
          label = NA_character_,
          stringsAsFactors = FALSE
        )
      )
    }
  }
  if (NROW(df)) {
    counts <- table(df$output_id[!is.na(df$capsule_id)])
    df$n_capsules <- as.integer(counts[df$output_id])
    df$n_capsules[is.na(df$n_capsules)] <- 0L
  } else {
    df$n_capsules <- integer()
  }
  df
}

#' Structural Audit of a Capsule Store
#'
#' Offline checks (no LLM): empty capsules, unknown members, cycles, orphans.
#'
#' @param store A `ks_capsule_store`.
#' @param study Optional `ks_study` for catalog membership checks.
#' @return A `ks_capsule_review` list with findings.
#' @export
review_capsules <- function(store, study = NULL) {
  if (!is_ks_capsule_store(store)) {
    cli::cli_abort("{.arg store} must be a {.cls ks_capsule_store} object.")
  }
  catalog_ids <- if (!is.null(study)) {
    if (!is_ks_study(study)) {
      cli::cli_abort("{.arg study} must be a {.cls ks_study} object.")
    }
    names(.capsule_catalog_contexts(study))
  } else {
    character()
  }

  findings <- character()
  caps <- store$capsules
  for (cid in names(caps)) {
    cap <- caps[[cid]]
    if (!length(cap$member_ids)) {
      findings <- c(findings, sprintf("Capsule '%s' has no members.", cid))
    }
    if (length(catalog_ids)) {
      unknown <- setdiff(cap$member_ids, catalog_ids)
      if (length(unknown)) {
        findings <- c(
          findings,
          sprintf(
            "Capsule '%s' references unknown member id(s): %s.",
            cid,
            paste(unknown, collapse = ", ")
          )
        )
      }
    }
    pid <- cap$parent_id
    if (!is.na(pid) && nzchar(pid) && !(pid %in% names(caps))) {
      findings <- c(findings, sprintf("Capsule '%s' parent '%s' is missing.", cid, pid))
    }
  }
  if (.capsule_has_cycle(caps)) {
    findings <- c(findings, "Capsule parent/child graph contains a cycle.")
  }
  if (length(catalog_ids)) {
    assigned <- unique(unlist(lapply(caps, `[[`, "member_ids"), use.names = FALSE))
    orphans <- setdiff(catalog_ids, assigned)
    if (length(orphans)) {
      findings <- c(
        findings,
        sprintf("Unassigned catalog id(s): %s.", paste(orphans, collapse = ", "))
      )
    }
    mem <- capsule_membership(store)
    multi <- unique(mem$output_id[mem$n_capsules > 1L])
    if (length(multi)) {
      findings <- c(
        findings,
        sprintf(
          "Multi-membership output id(s): %s.",
          paste(multi, collapse = ", ")
        )
      )
    }
  }

  structure(
    list(
      ok = !length(findings),
      findings = findings,
      n_capsules = length(caps),
      n_members = length(unique(unlist(lapply(caps, `[[`, "member_ids"), use.names = FALSE)))
    ),
    class = c("ks_capsule_review", "list")
  )
}

#' @export
print.ks_capsule_review <- function(x, ...) {
  cli::cli_h1("ks_capsule_review")
  cli::cli_text("{.strong Capsules}: {x$n_capsules}")
  cli::cli_text("{.strong Unique members}: {x$n_members}")
  if (isTRUE(x$ok)) {
    cli::cli_alert_success("No structural findings.")
  } else {
    cli::cli_alert_warning("{length(x$findings)} finding{?s}:")
    for (f in x$findings) cli::cli_li("{f}")
  }
  invisible(x)
}

#' Render Capsule Compact Text
#'
#' @param x A `ks_capsule`.
#' @param ... Unused.
#' @return Character scalar.
#' @rdname as_compact
#' @export
as_compact.ks_capsule <- function(x, ...) {
  paste(
    paste0("CAPSULE: ", x$capsule_id),
    paste0("LABEL: ", x$label),
    paste0("MEMBERS: ", paste(x$member_ids, collapse = ", ")),
    paste0("PARENT: ", x$parent_id %||% ""),
    "",
    x$compact_text %||% "",
    sep = "\n"
  )
}

#' Render Capsule as Markdown
#'
#' @param x A `ks_capsule`.
#' @param ... Unused.
#' @return Character scalar.
#' @rdname as_markdown
#' @export
as_markdown.ks_capsule <- function(x, ...) {
  paste(
    paste0("# Capsule ", x$capsule_id),
    "",
    paste0("- **Label**: ", x$label),
    paste0("- **Members**: ", paste(x$member_ids, collapse = ", ")),
    paste0("- **Parent**: ", x$parent_id %||% ""),
    paste0("- **Children**: ", paste(x$child_ids, collapse = ", ")),
    "",
    x$compact_text %||% "",
    sep = "\n"
  )
}

#' Detailed Member Content for One Capsule
#'
#' Expands full member contexts from a live [ks_study] (not truncated build
#' excerpts).
#'
#' @param store A `ks_capsule_store`.
#' @param capsule_id Capsule id.
#' @param study A `ks_study` containing the member contexts.
#' @param format `"compact"` or `"markdown"`.
#' @return Character scalar with concatenated member renders.
#' @export
capsule_content <- function(store,
                            capsule_id,
                            study,
                            format = c("compact", "markdown")) {
  if (!is_ks_capsule_store(store)) {
    cli::cli_abort("{.arg store} must be a {.cls ks_capsule_store} object.")
  }
  if (!is_ks_study(study)) {
    cli::cli_abort("{.arg study} must be a {.cls ks_study} object.")
  }
  checkmate::assert_string(capsule_id)
  format <- match.arg(format)
  if (!capsule_id %in% names(store$capsules)) {
    cli::cli_abort("Unknown capsule {.val {capsule_id}}.")
  }
  cap <- store$capsules[[capsule_id]]
  all <- .study_all(study)
  blocks <- lapply(cap$member_ids, function(mid) {
    ctx <- all[[mid]]
    if (is.null(ctx)) {
      return(paste0("### Missing member: ", mid))
    }
    body <- if (identical(format, "markdown")) as_markdown(ctx) else as_compact(ctx)
    paste0("### Member ", mid, "\n\n", body)
  })
  paste(
    paste0("## Capsule ", capsule_id, ": ", cap$label),
    "",
    paste(blocks, collapse = "\n\n"),
    sep = "\n"
  )
}

#' LLM Deep Review of Capsules
#'
#' Asks an LLM (typically vision-capable for figures) to critique capsule
#' grouping and member content.
#'
#' @param store A `ks_capsule_store`.
#' @param study A `ks_study` for member expansion and figure assets.
#' @param model LLM model name.
#' @param capsule_ids Optional subset of capsule ids (default: all).
#' @param provider LLM provider.
#' @param base_url Optional provider URL.
#' @param attach_images Logical. Attach figure images for vision models.
#' @param echo Echo mode for ellmer.
#' @param ... Extra args to the chat constructor.
#' @return A [ks_result].
#' @export
ks_review_capsules <- function(store,
                               study,
                               model,
                               capsule_ids = NULL,
                               provider = ks_get_option("provider"),
                               base_url = NULL,
                               attach_images = TRUE,
                               echo = "none",
                               ...) {
  if (!is_ks_capsule_store(store)) {
    cli::cli_abort("{.arg store} must be a {.cls ks_capsule_store} object.")
  }
  if (!is_ks_study(study)) {
    cli::cli_abort("{.arg study} must be a {.cls ks_study} object.")
  }
  checkmate::assert_string(model, min.chars = 1L)
  checkmate::assert_flag(attach_images)
  dots <- rlang::list2(...)

  ids <- capsule_ids %||% names(store$capsules)
  ids <- intersect(ids, names(store$capsules))
  context_txt <- paste(
    vapply(ids, function(cid) {
      capsule_content(store, cid, study, format = "compact")
    }, character(1)),
    collapse = "\n\n---\n\n"
  )
  tmpl <- tryCatch(.load_prompt("capsule_review"), error = function(e) NULL)
  if (is.null(tmpl)) {
    tmpl <- "Review these capsules:\n{{context}}"
  }
  prompt_txt <- .fill_prompt(tmpl, context = context_txt)

  system_prompt <- paste(
    "You are a senior clinical reviewer of semantic capsule groupings.",
    "Use attached figure images when present. Return a clear written review.",
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

  turn <- list(prompt_txt)
  if (attach_images) {
    all <- .study_all(study)
    for (cid in ids) {
      for (mid in store$capsules[[cid]]$member_ids) {
        ctx <- all[[mid]]
        img <- .capsule_image_content(ctx)
        if (!is.null(img)) {
          turn[[length(turn) + 1L]] <- paste0("Image for member ", mid, ":")
          turn[[length(turn) + 1L]] <- img
        }
      }
    }
  }
  response <- as.character(do.call(chat$chat, turn))
  new_ks_result(
    ids = ids,
    skill = "capsule_review",
    prompt = prompt_txt,
    response = response,
    model = model,
    provider = provider
  )
}

# ---------------------------------------------------------------------------
# Internal: classify / merge / validate
# ---------------------------------------------------------------------------

#' @keywords internal
#' @noRd
.capsule_catalog_contexts <- function(study) {
  all <- .study_all(study)
  keep <- vapply(all, function(ctx) {
    type <- as.character(ctx$type %||% "")
    type %in% c("Table", "Figure")
  }, logical(1))
  all[keep]
}

#' @keywords internal
#' @noRd
.make_capsule_classify_chat <- function(model, provider, base_url, dots = list()) {
  system_prompt <- paste(
    "You classify clinical statistical tables and figures into semantic capsules.",
    "Group by information meaning only — never by CDISC domains, ICH numbers, or filenames.",
    "Titles may be in any language. Use attached figure images when present.",
    "Return strict JSON only with key \"capsules\" (array of objects with",
    "capsule_id, label, parent_id, member_ids, confidence).",
    "Multi-membership is allowed. Do not invent member ids.",
    sep = " "
  )
  chat <- tryCatch(
    rlang::exec(
      .make_ellmer_chat,
      provider = provider,
      model = model,
      system_prompt = system_prompt,
      base_url = base_url,
      echo = "none",
      !!!dots
    ),
    error = function(e) {
      cli::cli_abort(c(
        "Could not create LLM chat for {.fn as_capsules}.",
        x = conditionMessage(e)
      ))
    }
  )
  chat
}

#' @keywords internal
#' @noRd
.capsule_excerpt <- function(ctx, max_excerpt_rows = 12L, detail = "compact") {
  if (identical(detail, "full")) {
    return(as_compact(ctx))
  }
  # Truncate table rows for compact classify prompts.
  if (identical(ctx$type, "Table") && length(ctx$rows) > max_excerpt_rows) {
    ctx2 <- ctx
    ctx2$rows <- ctx$rows[seq_len(max_excerpt_rows)]
    return(as_compact(ctx2))
  }
  as_compact(ctx)
}

#' @keywords internal
#' @noRd
.capsule_catalog_text <- function(catalog, max_excerpt_rows = 12L, detail = "compact") {
  blocks <- vapply(names(catalog), function(id) {
    ctx <- catalog[[id]]
    paste(
      paste0("### ", id),
      paste0("type: ", ctx$type %||% ""),
      paste0("title: ", paste(ctx$title %||% character(), collapse = " — ")),
      paste0("subtitles: ", paste(ctx$subtitles %||% character(), collapse = " — ")),
      paste0("population: ", ctx$population %||% ""),
      paste0("source: ", ctx$source %||% ""),
      "content_excerpt:",
      .capsule_excerpt(ctx, max_excerpt_rows = max_excerpt_rows, detail = detail),
      sep = "\n"
    )
  }, character(1))
  paste(blocks, collapse = "\n\n")
}

#' Attach a figure image for ellmer (converts SVG via magick when needed).
#'
#' Does not interpret plot content — only prepares bytes for a vision model.
#'
#' @keywords internal
#' @noRd
.capsule_image_content <- function(ctx) {
  if (is.null(ctx) || !identical(ctx$type, "Figure")) {
    return(NULL)
  }
  path <- ctx$asset_path %||% NA_character_
  if (is.na(path) || !nzchar(path) || !file.exists(path)) {
    return(NULL)
  }
  ext <- tolower(tools::file_ext(path))
  attach_path <- path
  tmp <- NULL
  on.exit({
    if (!is.null(tmp) && file.exists(tmp)) unlink(tmp)
  }, add = TRUE)

  if (!ext %in% c("png", "jpeg", "jpg", "webp", "gif")) {
    if (!requireNamespace("magick", quietly = TRUE)) {
      cli::cli_warn(c(
        "Cannot attach figure {.path {path}}:",
        i = "Install {.pkg magick} to convert {.val {ext}} for vision models."
      ))
      return(NULL)
    }
    tmp <- tempfile(fileext = ".png")
    ok <- tryCatch(
      {
        img <- magick::image_read(path)
        magick::image_write(img, path = tmp, format = "png")
        TRUE
      },
      error = function(e) {
        cli::cli_warn(c(
          "Failed to convert figure {.path {path}} for vision.",
          x = conditionMessage(e)
        ))
        FALSE
      }
    )
    if (!isTRUE(ok)) {
      return(NULL)
    }
    attach_path <- tmp
  }

  tryCatch(
    ellmer::content_image_file(attach_path, resize = "low"),
    error = function(e) {
      cli::cli_warn(c(
        "Could not attach figure image {.path {path}}.",
        x = conditionMessage(e)
      ))
      NULL
    }
  )
}

#' @keywords internal
#' @noRd
.capsule_classify_chunk <- function(chat,
                                    catalog,
                                    max_excerpt_rows = 12L,
                                    detail = "compact",
                                    attach_images = TRUE) {
  catalog_txt <- .capsule_catalog_text(
    catalog,
    max_excerpt_rows = max_excerpt_rows,
    detail = detail
  )
  tmpl <- tryCatch(.load_prompt("capsule_classify"), error = function(e) NULL)
  if (is.null(tmpl)) {
    tmpl <- "Classify into capsules. Catalog:\n{{catalog}}"
  }
  prompt_txt <- .fill_prompt(tmpl, catalog = catalog_txt)

  turn <- list(prompt_txt)
  if (attach_images) {
    for (id in names(catalog)) {
      img <- .capsule_image_content(catalog[[id]])
      if (!is.null(img)) {
        turn[[length(turn) + 1L]] <- paste0("Figure image for id ", id, ":")
        turn[[length(turn) + 1L]] <- img
      }
    }
  }

  out <- tryCatch(
    as.character(do.call(chat$chat, turn)),
    error = function(e) {
      cli::cli_abort(c(
        "Capsule classification LLM call failed.",
        x = conditionMessage(e)
      ))
    }
  )
  .capsule_parse_classify_json(out)
}

#' @keywords internal
#' @noRd
.capsule_llm_merge <- function(chat, partials, catalog_ids) {
  payload <- jsonlite::toJSON(
    list(
      catalog_ids = catalog_ids,
      partial_trees = partials
    ),
    auto_unbox = TRUE,
    null = "null",
    pretty = TRUE
  )
  req <- paste(
    "Merge these partial capsule trees into one coherent tree.",
    "Preserve multi-membership when justified. Use only catalog_ids as members.",
    "Return the same JSON schema: {\"capsules\":[...]} only.",
    "Partial results:",
    as.character(payload),
    sep = "\n\n"
  )
  out <- tryCatch(
    as.character(chat$chat(req)),
    error = function(e) {
      cli::cli_abort(c(
        "Capsule merge LLM call failed.",
        x = conditionMessage(e)
      ))
    }
  )
  .capsule_parse_classify_json(out)
}

#' @keywords internal
#' @noRd
.capsule_parse_classify_json <- function(out) {
  if (is.null(out) || !nzchar(out)) {
    cli::cli_abort("Capsule LLM returned an empty response.")
  }
  parsed <- tryCatch(jsonlite::fromJSON(out, simplifyVector = FALSE), error = function(e) NULL)
  if (is.null(parsed)) {
    json_block <- regmatches(out, regexpr("\\{[\\s\\S]*\\}", out, perl = TRUE))
    if (length(json_block) == 1L && nzchar(json_block[[1]])) {
      parsed <- tryCatch(
        jsonlite::fromJSON(json_block[[1]], simplifyVector = FALSE),
        error = function(e) NULL
      )
    }
  }
  if (is.null(parsed) || is.null(parsed$capsules)) {
    cli::cli_abort("Capsule LLM response was not valid JSON with a {.field capsules} array.")
  }
  parsed$capsules
}

#' @keywords internal
#' @noRd
.capsule_safe_id <- function(x) {
  x <- tolower(as.character(x))
  x <- gsub("[^a-z0-9]+", "_", x)
  x <- gsub("^_+|_+$", "", x)
  if (!nzchar(x)) "capsule" else x
}

#' @keywords internal
#' @noRd
.capsule_validate_and_build <- function(raw_caps,
                                        catalog,
                                        min_confidence = 0.5,
                                        max_excerpt_rows = 12L,
                                        detail = "compact") {
  catalog_ids <- names(catalog)
  capsules <- list()
  used_ids <- character()

  for (raw in raw_caps) {
    cid <- .capsule_safe_id(raw$capsule_id %||% raw$id %||% "")
    if (!nzchar(cid)) next
    # Disambiguate duplicate ids from the model.
    base <- cid
    k <- 2L
    while (cid %in% used_ids) {
      cid <- paste0(base, "_", k)
      k <- k + 1L
    }
    conf <- suppressWarnings(as.numeric(raw$confidence %||% 1))
    if (!is.finite(conf)) conf <- 1
    if (conf < min_confidence) next

    members <- unique(as.character(unlist(raw$member_ids) %||% character()))
    members <- intersect(members, catalog_ids)
    if (!length(members)) next

    parent_id <- raw$parent_id %||% NA_character_
    if (is.null(parent_id) || identical(parent_id, "null") || !nzchar(as.character(parent_id))) {
      parent_id <- NA_character_
    } else {
      parent_id <- .capsule_safe_id(parent_id)
    }

    pops <- unique(vapply(members, function(mid) {
      as.character(catalog[[mid]]$population %||% NA_character_)
    }, character(1)))
    pops <- pops[!is.na(pops) & nzchar(pops)]
    population <- if (length(pops) == 1L) pops[[1]] else NA_character_

    compact_bits <- vapply(members, function(mid) {
      .capsule_excerpt(
        catalog[[mid]],
        max_excerpt_rows = max_excerpt_rows,
        detail = detail
      )
    }, character(1))

    capsules[[cid]] <- new_ks_capsule(
      capsule_id = cid,
      label = as.character(raw$label %||% cid),
      member_ids = members,
      parent_id = parent_id,
      child_ids = character(),
      population = population,
      compact_text = paste(compact_bits, collapse = "\n\n"),
      confidence = conf
    )
    used_ids <- c(used_ids, cid)
  }

  # Drop parent links that point outside the accepted set; then wire children.
  for (cid in names(capsules)) {
    pid <- capsules[[cid]]$parent_id
    if (!is.na(pid) && nzchar(pid) && !(pid %in% names(capsules))) {
      capsules[[cid]]$parent_id <- NA_character_
    }
    if (!is.na(pid) && identical(pid, cid)) {
      capsules[[cid]]$parent_id <- NA_character_
    }
  }
  capsules <- .wire_capsule_children(capsules)
  if (.capsule_has_cycle(capsules)) {
    # Break cycles by clearing parents that participate in a cycle.
    for (cid in names(capsules)) {
      capsules[[cid]]$parent_id <- NA_character_
      capsules[[cid]]$child_ids <- character()
    }
    cli::cli_warn("Capsule tree had a cycle; parent links were cleared.")
  } else {
    capsules <- .wire_capsule_children(capsules)
  }
  capsules
}

#' @keywords internal
#' @noRd
.wire_capsule_children <- function(capsules) {
  id_to_children <- lapply(names(capsules), function(nm) character())
  names(id_to_children) <- names(capsules)
  for (nm in names(capsules)) {
    p <- capsules[[nm]]$parent_id
    if (!is.na(p) && nzchar(p) && p %in% names(id_to_children)) {
      id_to_children[[p]] <- c(id_to_children[[p]], nm)
    }
  }
  for (nm in names(capsules)) {
    capsules[[nm]]$child_ids <- unique(as.character(id_to_children[[nm]]))
  }
  capsules
}

#' @keywords internal
#' @noRd
.capsule_has_cycle <- function(capsules) {
  if (!length(capsules)) return(FALSE)
  visiting <- character()
  visited <- character()
  dfs <- function(cid) {
    if (cid %in% visiting) return(TRUE)
    if (cid %in% visited) return(FALSE)
    visiting <<- c(visiting, cid)
    for (ch in capsules[[cid]]$child_ids %||% character()) {
      if (ch %in% names(capsules) && dfs(ch)) return(TRUE)
    }
    visiting <<- setdiff(visiting, cid)
    visited <<- c(visited, cid)
    FALSE
  }
  for (cid in names(capsules)) {
    if (dfs(cid)) return(TRUE)
  }
  FALSE
}
