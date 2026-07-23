## Clinical capsules: concept-centric, traceable summaries over ks_context rows.

# ---------------------------------------------------------------------------
# Constructors / predicates
# ---------------------------------------------------------------------------

#' @keywords internal
#' @noRd
new_ks_capsule <- function(capsule_id,
                           source_id,
                           source_rows = integer(),
                           domain = "UNKNOWN",
                           level = "ROW",
                           label = "",
                           population = NA_character_,
                           parent_id = NA_character_,
                           child_ids = character(),
                           linked_ids = character(),
                           stats = list(),
                           compact_text = "",
                           concepts = character(),
                           keywords = character(),
                           embedding = NULL,
                           synonyms = character()) {
  structure(
    list(
      capsule_id = as.character(capsule_id),
      source_id = as.character(source_id),
      source_rows = as.integer(source_rows),
      domain = as.character(domain),
      level = as.character(level),
      label = as.character(label),
      population = as.character(population),
      parent_id = as.character(parent_id),
      child_ids = as.character(child_ids),
      linked_ids = as.character(linked_ids),
      stats = stats %||% list(),
      compact_text = as.character(compact_text),
      concepts = as.character(concepts),
      keywords = as.character(keywords),
      embedding = embedding,
      synonyms = as.character(synonyms)
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
#' A `ks_capsule` is a concept-centric, traceable semantic unit derived from a
#' [ks_context] row group (for example OVERALL, SOC, PT). Each capsule stores
#' compact text, parsed statistics, hierarchy links, and optional embeddings.
#'
#' @param x An object.
#' @return `TRUE` if `x` is a `ks_capsule`, otherwise `FALSE`.
#' @export
is_ks_capsule <- function(x) {
  inherits(x, "ks_capsule")
}

#' The `ks_capsule_store` Class
#'
#' A `ks_capsule_store` is a named registry of [ks_capsule] objects produced by
#' [as_capsules()], with study-level metadata for persistence and retrieval.
#'
#' @param x An object.
#' @return `TRUE` if `x` is a `ks_capsule_store`, otherwise `FALSE`.
#' @export
is_ks_capsule_store <- function(x) {
  inherits(x, "ks_capsule_store")
}

#' @export
print.ks_capsule <- function(x, ...) {
  cli::cli_h1("ks_capsule: {x$capsule_id}")
  cli::cli_text("{.strong Source}: {x$source_id}")
  cli::cli_text("{.strong Domain}: {x$domain} ({x$level})")
  cli::cli_text("{.strong Label}: {x$label}")
  cli::cli_text("{.strong Rows}: {if (length(x$source_rows)) paste(range(x$source_rows), collapse = '...') else '(none)'}")
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
# as_capsules
# ---------------------------------------------------------------------------

#' Build Clinical Capsules from Contexts
#'
#' Converts one [ks_context] (or all contexts in a [ks_study]) into a
#' concept-centric capsule registry suitable for semantic enrichment,
#' retrieval, and progressive-disclosure reasoning.
#'
#' Domain codes are inferred once per output (language-agnostic rules first).
#' Pass `model` to ask a small local LLM when rules leave the domain
#' `UNKNOWN` (default), or always after hard signals (`llm_domain = "always"`).
#' The chat is created once per call and reused across tables in a study.
#'
#' @param x A `ks_context` or `ks_study`.
#' @param model Optional small LLM for domain classification (e.g. a 4B
#'   local model). `NULL` keeps deterministic inference only.
#' @param provider LLM provider. Defaults to [ks_get_option()]`"provider"`.
#' @param base_url Optional provider URL override.
#' @param llm_domain When to call the model: `"unknown"` (default — only if
#'   rules yield `UNKNOWN`), `"always"` (after annotation / `domain_map` /
#'   MedDRA structure; lexicon and id are fallbacks), or `"never"`.
#' @param llm_min_confidence Minimum confidence (0–1) to accept an LLM
#'   domain. Below this, rules continue / return `UNKNOWN`.
#' @param ... Extra args forwarded to the ellmer chat constructor.
#'
#' @return A `ks_capsule_store`.
#' @export
as_capsules <- function(x, ...) {
  UseMethod("as_capsules")
}

#' @rdname as_capsules
#' @export
as_capsules.ks_context <- function(x,
                                   model = NULL,
                                   provider = ks_get_option("provider"),
                                   base_url = NULL,
                                   llm_domain = c("unknown", "always", "never"),
                                   llm_min_confidence = 0.5,
                                   ...) {
  llm_domain <- match.arg(llm_domain)
  dots <- rlang::list2(...)
  chat <- .make_domain_llm_chat(
    model = model,
    provider = provider,
    base_url = base_url,
    llm_domain = llm_domain,
    dots = dots
  )
  .as_capsules_context(
    x,
    chat = chat,
    llm_domain = llm_domain,
    llm_min_confidence = llm_min_confidence
  )
}

#' @rdname as_capsules
#' @export
as_capsules.ks_study <- function(x,
                                 model = NULL,
                                 provider = ks_get_option("provider"),
                                 base_url = NULL,
                                 llm_domain = c("unknown", "always", "never"),
                                 llm_min_confidence = 0.5,
                                 ...) {
  llm_domain <- match.arg(llm_domain)
  dots <- rlang::list2(...)
  chat <- .make_domain_llm_chat(
    model = model,
    provider = provider,
    base_url = base_url,
    llm_domain = llm_domain,
    dots = dots
  )
  all <- .study_all(x)
  if (!length(all)) {
    return(new_ks_capsule_store(capsules = list(), meta_dir = x$meta_dir))
  }
  pieces <- lapply(names(all), function(id) {
    ctx <- all[[id]]
    tryCatch(
      .as_capsules_context(
        ctx,
        chat = chat,
        llm_domain = llm_domain,
        llm_min_confidence = llm_min_confidence
      ),
      error = function(e) {
        cli::cli_warn(c(
          "Skipping capsule build for output {.val {id}}.",
          x = conditionMessage(e)
        ))
        new_ks_capsule_store(capsules = list())
      }
    )
  })
  caps <- Reduce(c, lapply(pieces, function(s) s$capsules))
  if (is.null(caps)) {
    caps <- list()
  }
  caps <- .link_capsules_to_text_outputs(
    caps,
    x,
    chat = chat,
    llm_domain = llm_domain,
    llm_min_confidence = llm_min_confidence
  )
  new_ks_capsule_store(
    capsules = caps,
    study_id = if (!is.null(x$meta_dir)) basename(x$meta_dir) else NULL,
    meta_dir = x$meta_dir
  )
}

#' @keywords internal
#' @noRd
.as_capsules_context <- function(x,
                                 chat = NULL,
                                 llm_domain = "unknown",
                                 llm_min_confidence = 0.5) {
  if (!length(x$rows)) {
    return(new_ks_capsule_store(capsules = list()))
  }

  domain <- .capsule_infer_domain(
    x,
    chat = chat,
    llm_domain = llm_domain,
    llm_min_confidence = llm_min_confidence
  )

  row_label_col <- .capsule_row_label_col(x)
  groups <- .capsule_groups_from_rows(x$rows, row_label_col)
  ids <- vapply(groups, function(g) {
    paste(x$id, g$level, .capsule_safe_id(if (nzchar(g$label)) g$label else paste0("ROW_", g$idx)), sep = "::")
  }, character(1))
  parent_ids <- rep(NA_character_, length(groups))
  overall_id <- NA_character_
  sec_parent <- list()
  for (i in seq_along(groups)) {
    g <- groups[[i]]
    if (identical(g$level, "OVERALL")) {
      overall_id <- ids[[i]]
    } else if (identical(g$level, "SOC")) {
      parent_ids[[i]] <- overall_id
      sec_key <- if (!is.null(g$section) && !is.na(g$section) && nzchar(g$section)) {
        g$section
      } else {
        g$label
      }
      sec_parent[[sec_key]] <- ids[[i]]
    } else if (identical(g$level, "PT")) {
      sec_key <- g$section %||% ""
      parent_ids[[i]] <- sec_parent[[sec_key]] %||% overall_id
    } else {
      parent_ids[[i]] <- overall_id
    }
  }

  capsules <- lapply(seq_along(groups), function(i) {
    g <- groups[[i]]
    .capsule_from_group(
      x, g, row_label_col,
      capsule_id = ids[[i]],
      parent_id = parent_ids[[i]],
      domain = domain
    )
  })
  names(capsules) <- vapply(capsules, function(c) c$capsule_id, character(1))
  capsules <- .wire_capsule_children(capsules)
  new_ks_capsule_store(capsules = capsules)
}

# ---------------------------------------------------------------------------
# Persistence
# ---------------------------------------------------------------------------

#' Save a Capsule Store to a `.ksc` File
#'
#' @param store A `ks_capsule_store`.
#' @param path Output path. If extension is missing, `.ksc` is appended.
#' @return Invisibly, written path.
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
    new_ks_capsule(
      capsule_id = c$capsule_id %||% "",
      source_id = c$source_id %||% "",
      source_rows = as.integer(unlist(c$source_rows) %||% integer()),
      domain = c$domain %||% "UNKNOWN",
      level = c$level %||% "ROW",
      label = c$label %||% "",
      population = c$population %||% NA_character_,
      parent_id = c$parent_id %||% NA_character_,
      child_ids = as.character(unlist(c$child_ids) %||% character()),
      linked_ids = as.character(unlist(c$linked_ids) %||% character()),
      stats = c$stats %||% list(),
      compact_text = c$compact_text %||% "",
      concepts = as.character(unlist(c$concepts) %||% character()),
      keywords = as.character(unlist(c$keywords) %||% character()),
      embedding = if (is.null(c$embedding)) NULL else as.numeric(unlist(c$embedding)),
      synonyms = as.character(unlist(c$synonyms) %||% character())
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
# Internal helpers
# ---------------------------------------------------------------------------

#' @keywords internal
#' @noRd
.capsule_row_label_col <- function(ctx) {
  if (!length(ctx$columns)) {
    return(NA_character_)
  }
  as.character(ctx$columns[[1]]$name %||% NA_character_)
}

#' @keywords internal
#' @noRd
.capsule_groups_from_rows <- function(rows, row_label_col) {
  out <- vector("list", length(rows))
  for (i in seq_along(rows)) {
    row <- rows[[i]]
    label <- ""
    if (!is.na(row_label_col) && !is.null(row$cells[[row_label_col]])) {
      label <- as.character(row$cells[[row_label_col]])
    }
    section <- row$section %||% NA_character_
    kind <- toupper(as.character(row$kind %||% ""))
    level <- if (identical(kind, "OVERALL")) {
      "OVERALL"
    } else if (identical(kind, "SOC")) {
      "SOC"
    } else if (identical(kind, "PT")) {
      "PT"
    } else if (!is.null(section) && !is.na(section) && nzchar(section) &&
               identical(toupper(trimws(label)), toupper(trimws(section)))) {
      "SOC"
    } else if (!is.null(section) && !is.na(section) && nzchar(section)) {
      "PT"
    } else if (i == 1L) {
      "OVERALL"
    } else {
      "PARAM"
    }
    out[[i]] <- list(
      idx = i,
      rows = i,
      label = label,
      section = section,
      level = level
    )
  }
  # Add synthetic SOC capsules for section blocks when not explicitly present.
  secs <- unique(vapply(out, function(g) as.character(g$section %||% NA_character_), character(1)))
  secs <- secs[!is.na(secs) & nzchar(secs)]
  if (length(secs)) {
    for (sec in secs) {
      in_sec <- which(vapply(out, function(g) identical(as.character(g$section %||% ""), sec), logical(1)))
      has_soc <- any(vapply(out[in_sec], function(g) identical(g$level, "SOC"), logical(1)))
      if (!has_soc) {
        out[[length(out) + 1L]] <- list(
          idx = in_sec[[1]],
          rows = in_sec,
          label = sec,
          section = sec,
          level = "SOC"
        )
        # Re-label row-level entries in this section as PT unless explicitly OVERALL.
        for (j in in_sec) {
          if (!identical(out[[j]]$level, "OVERALL")) {
            out[[j]]$level <- "PT"
          }
        }
      }
    }
  }
  # Ensure stable order by first row index then level priority.
  pr <- function(level) {
    if (identical(level, "OVERALL")) return(1L)
    if (identical(level, "SOC")) return(2L)
    if (identical(level, "PT")) return(3L)
    4L
  }
  ord <- order(
    vapply(out, `[[`, integer(1), "idx"),
    vapply(out, function(g) pr(g$level), integer(1))
  )
  out <- out[ord]
  out
}

#' @keywords internal
#' @noRd
.capsule_from_group <- function(ctx, g, row_label_col, capsule_id, parent_id,
                                domain = NULL) {
  idx <- g$idx
  row <- ctx$rows[[idx]]
  source_rows <- as.integer(g$rows %||% idx)
  label <- if (nzchar(g$label)) g$label else paste0("ROW_", idx)
  stats <- .capsule_extract_stats(row$cells, row_label_col, ctx$span_headers)
  compact_text <- .capsule_compact_for_rows(ctx, source_rows)
  if (is.null(domain)) {
    domain <- .capsule_infer_domain(ctx)
  }
  new_ks_capsule(
    capsule_id = capsule_id,
    source_id = ctx$id,
    source_rows = source_rows,
    domain = domain,
    level = g$level,
    label = label,
    population = ctx$population %||% NA_character_,
    parent_id = parent_id,
    child_ids = character(),
    linked_ids = character(),
    stats = stats,
    compact_text = compact_text
  )
}

#' @keywords internal
#' @noRd
.capsule_safe_id <- function(x) {
  x <- toupper(as.character(x))
  x <- gsub("[^A-Z0-9]+", "_", x)
  x <- gsub("^_+|_+$", "", x)
  if (!nzchar(x)) {
    "ROW"
  } else {
    x
  }
}

#' @keywords internal
#' @noRd
.capsule_extract_stats <- function(cells, row_label_col, span_headers) {
  keys <- setdiff(names(cells), row_label_col)
  out <- list(raw = list())
  if (!length(keys)) {
    return(out)
  }

  parse_npct <- function(v) {
    m <- regexec("^(\\d+)\\s*\\((\\d+\\.?\\d*)%\\)$", v)
    hit <- regmatches(v, m)[[1]]
    if (length(hit) == 3L) {
      list(n = as.integer(hit[[2]]), pct = as.numeric(hit[[3]]))
    } else {
      NULL
    }
  }
  parse_events <- function(v) {
    m <- regexec("^\\[(\\d+)\\]$", v)
    hit <- regmatches(v, m)[[1]]
    if (length(hit) == 2L) as.integer(hit[[2]]) else NULL
  }
  parse_p <- function(v) {
    vv <- trimws(v)
    if (grepl("^>?\\.?\\d", vv)) {
      suppressWarnings(as.numeric(sub("^>", "", vv)))
    } else {
      NA_real_
    }
  }

  group_for_col <- function(col) {
    if (!length(span_headers)) {
      return(col)
    }
    for (sp in span_headers) {
      if (col %in% (sp$cols %||% character())) {
        return(sp$label %||% col)
      }
    }
    col
  }

  for (nm in keys) {
    v <- as.character(cells[[nm]] %||% "")
    grp <- group_for_col(nm)
    if (is.null(out[[grp]])) out[[grp]] <- list()
    np <- parse_npct(v)
    ev <- parse_events(v)
    pv <- parse_p(v)
    if (!is.null(np)) out[[grp]] <- utils::modifyList(out[[grp]], np)
    if (!is.null(ev)) out[[grp]]$events <- ev
    if (!is.na(pv) && grepl("^P_|_P$|PVALUE|PVAL|P_", toupper(nm))) {
      out[[grp]][[tolower(nm)]] <- pv
    }
    if (is.null(np) && is.null(ev) && is.na(pv)) {
      out$raw[[nm]] <- v
    }
  }
  out
}

#' @keywords internal
#' @noRd
.capsule_compact_for_rows <- function(ctx, idx) {
  if (!length(ctx$rows)) {
    return("")
  }
  sub_ctx <- new_ks_context(
    id = ctx$id,
    type = ctx$type,
    title = ctx$title,
    subtitles = ctx$subtitles,
    population = ctx$population,
    source = ctx$source,
    columns = ctx$columns,
    span_headers = ctx$span_headers,
    rows = ctx$rows[idx],
    n_rows_total = length(idx),
    footnotes = ctx$footnotes,
    annotations = ctx$annotations,
    warnings = character()
  )
  as_compact(sub_ctx)
}

#' Infer a clinical domain code for a context (language-agnostic).
#'
#' Priority (first hit wins):
#' 1. Explicit `ctx$annotations$domain` (set via [enrich_context()]).
#' 2. Session `domain_map` option (exact output id, then regex keys).
#' 3. Structural cues from rows (`ROW_KIND` SOC/PT → AE) — no language needed.
#' 4. Optional small LLM when `llm_domain = "always"` and `chat` is set.
#' 5. Multilingual title/subtitle/source keyword lexicon.
#' 6. ICH/CSR-style output id numbering (`14-5.x` → AE, `14-6.x` → LB, …).
#' 7. Optional small LLM when `llm_domain = "unknown"` and still unresolved.
#' 8. `"UNKNOWN"`.
#'
#' @keywords internal
#' @noRd
.capsule_infer_domain <- function(ctx,
                                  chat = NULL,
                                  llm_domain = "unknown",
                                  llm_min_confidence = 0.5) {
  # 1. Explicit annotation override (any language / custom study taxonomy).
  ann <- ctx$annotations %||% list()
  if (!is.null(ann$domain) && nzchar(as.character(ann$domain)[[1]])) {
    return(toupper(as.character(ann$domain)[[1]]))
  }

  # 2. User domain_map: exact id, then regex patterns.
  mapped <- .capsule_domain_from_map(ctx$id %||% "")
  if (!is.null(mapped)) {
    return(mapped)
  }

  # 3. Structure from MedDRA-like hierarchy markers (language-independent).
  if (.capsule_has_ae_structure(ctx)) {
    return("AE")
  }

  # 4. Optional LLM before soft lexical / id heuristics.
  if (identical(llm_domain, "always") && !is.null(chat)) {
    hit <- .capsule_domain_from_llm(ctx, chat, llm_min_confidence)
    if (!is.null(hit) && !identical(hit, "UNKNOWN")) {
      return(hit)
    }
  }

  # 5. Multilingual lexical cues in title / subtitles / source.
  lex <- .capsule_domain_from_lexicon(ctx)
  if (!is.null(lex)) {
    return(lex)
  }

  # 6. CSR / ICH table-number conventions encoded in the output id.
  by_id <- .capsule_domain_from_id(ctx$id %||% "")
  if (!is.null(by_id)) {
    return(by_id)
  }

  # 7. Optional LLM fallback when rules leave the domain unresolved.
  if (identical(llm_domain, "unknown") && !is.null(chat)) {
    hit <- .capsule_domain_from_llm(ctx, chat, llm_min_confidence)
    if (!is.null(hit) && !identical(hit, "UNKNOWN")) {
      return(hit)
    }
  }

  "UNKNOWN"
}

#' @keywords internal
#' @noRd
.capsule_allowed_domains <- function() {
  c("AE", "DM", "VS", "LB", "EFFC", "EX", "DS", "UNKNOWN")
}

#' @keywords internal
#' @noRd
.capsule_normalize_domain <- function(x) {
  if (is.null(x) || !length(x)) {
    return(NULL)
  }
  x <- toupper(trimws(as.character(x)[[1]]))
  if (!nzchar(x)) {
    return(NULL)
  }
  aliases <- c(
    LAB = "LB", LABORATORY = "LB", LABS = "LB",
    DEMO = "DM", DEMOGRAPHICS = "DM", DEMOGRAPHY = "DM",
    EFFICACY = "EFFC", EFF = "EFFC",
    VITAL = "VS", VITALS = "VS",
    ADVERSE = "AE", TEAE = "AE", SAE = "AE",
    EXPOSURE = "EX", DISPOSITION = "DS", POPULATION = "DS"
  )
  if (x %in% names(aliases)) {
    x <- unname(aliases[[x]])
  }
  if (x %in% .capsule_allowed_domains()) {
    x
  } else {
    NULL
  }
}

#' @keywords internal
#' @noRd
.make_domain_llm_chat <- function(model,
                                  provider,
                                  base_url,
                                  llm_domain = "unknown",
                                  dots = list()) {
  if (identical(llm_domain, "never")) {
    return(NULL)
  }
  if (is.null(model) || !nzchar(as.character(model)[[1]])) {
    return(NULL)
  }
  system_prompt <- paste(
    "You classify clinical statistical outputs into CDISC-like domains.",
    "Return strict JSON only: {\"domain\":\"CODE\",\"confidence\":0.0}.",
    "Allowed domain codes:",
    paste(.capsule_allowed_domains(), collapse = ", "),
    "Use UNKNOWN if unsure. Never invent other codes.",
    "Titles may be in any language.",
    sep = " "
  )
  tryCatch(
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
      cli::cli_warn(c(
        "Domain LLM chat could not be created; using rule-based domains only.",
        x = conditionMessage(e)
      ))
      NULL
    }
  )
}

#' @keywords internal
#' @noRd
.capsule_domain_llm_prompt <- function(ctx) {
  n_show <- min(8L, length(ctx$rows))
  row_bits <- character(0)
  if (n_show > 0L) {
    row_bits <- vapply(seq_len(n_show), function(i) {
      r <- ctx$rows[[i]]
      lab <- ""
      if (length(r$cells)) {
        lab <- as.character(r$cells[[1]] %||% "")
      }
      sprintf("%s|%s", as.character(r$kind %||% ""), lab)
    }, character(1))
  }
  paste(
    "Classify this clinical output domain.",
    paste0("id: ", ctx$id %||% ""),
    paste0("type: ", ctx$type %||% ""),
    paste0("title: ", paste(ctx$title %||% character(), collapse = " — ")),
    paste0("subtitles: ", paste(ctx$subtitles %||% character(), collapse = " — ")),
    paste0("source: ", ctx$source %||% ""),
    paste0("population: ", ctx$population %||% ""),
    paste0("row_kinds_and_labels: ", paste(row_bits, collapse = "; ")),
    "Return JSON {\"domain\":\"CODE\",\"confidence\":0.0}.",
    sep = "\n"
  )
}

#' @keywords internal
#' @noRd
.capsule_parse_domain_llm_json <- function(out) {
  if (is.null(out) || !nzchar(out)) {
    return(NULL)
  }
  parsed <- tryCatch(jsonlite::fromJSON(out, simplifyVector = TRUE), error = function(e) NULL)
  if (is.null(parsed)) {
    json_block <- regmatches(out, regexpr("\\{[\\s\\S]*\\}", out, perl = TRUE))
    if (length(json_block) == 1L && nzchar(json_block[[1]])) {
      parsed <- tryCatch(
        jsonlite::fromJSON(json_block[[1]], simplifyVector = TRUE),
        error = function(e) NULL
      )
    }
  }
  parsed
}

#' @keywords internal
#' @noRd
.capsule_domain_from_llm <- function(ctx, chat, min_confidence = 0.5) {
  if (is.null(chat)) {
    return(NULL)
  }
  req <- .capsule_domain_llm_prompt(ctx)
  out <- tryCatch(as.character(chat$chat(req)), error = function(e) NULL)
  parsed <- .capsule_parse_domain_llm_json(out)
  if (is.null(parsed)) {
    return(NULL)
  }
  dom <- .capsule_normalize_domain(parsed$domain)
  if (is.null(dom)) {
    return(NULL)
  }
  conf <- suppressWarnings(as.numeric(parsed$confidence %||% 1))
  if (!is.finite(conf)) {
    conf <- 1
  }
  if (conf < min_confidence) {
    return(NULL)
  }
  dom
}

#' @keywords internal
#' @noRd
.capsule_domain_from_map <- function(id) {
  id <- as.character(id %||% "")
  if (!nzchar(id)) {
    return(NULL)
  }
  dm <- ks_get_option("domain_map")
  if (is.null(dm) || !length(dm)) {
    return(NULL)
  }
  dm <- unlist(dm)
  if (is.null(names(dm)) || any(names(dm) == "")) {
    return(NULL)
  }
  # Exact id match first.
  if (id %in% names(dm)) {
    return(toupper(as.character(unname(dm[[id]]))))
  }
  # Then regex keys (e.g. "^14-5", "^табл-ндя").
  for (pat in names(dm)) {
    ok <- tryCatch(
      grepl(pat, id, ignore.case = TRUE, perl = TRUE),
      error = function(e) FALSE
    )
    if (isTRUE(ok)) {
      return(toupper(as.character(unname(dm[[pat]]))))
    }
  }
  NULL
}

#' @keywords internal
#' @noRd
.capsule_has_ae_structure <- function(ctx) {
  if (!length(ctx$rows)) {
    return(FALSE)
  }
  kinds <- toupper(vapply(ctx$rows, function(r) {
    as.character(r$kind %||% "")
  }, character(1)))
  any(kinds %in% c("SOC", "PT", "HLGT", "HLT", "LLT"))
}

#' Multilingual keyword lexicon for domain inference.
#'
#' Patterns are matched against a lowercased concatenation of title, subtitles,
#' and source. Keep this list conservative: prefer structure / id / domain_map
#' for ambiguous words (e.g. English "baseline" alone is NOT mapped to DM).
#'
#' @keywords internal
#' @noRd
.capsule_domain_lexicon <- function() {
  list(
    AE = paste(
      # EN
      "adverse", "teae", "\\bsae\\b", "\\bae\\b", "meddra", "preferred term",
      "system organ class",
      # DE
      "unerw(?:u|ü)nscht", "nebenwirkung",
      # FR
      "ind(?:e|é)sirable",
      # ES / PT
      "advers[oa]", "acontecimiento advers", "evento advers",
      # IT
      "avvers",
      # RU
      "нежелательн", "ндя", "серьезн.*событ",
      "предпочтительн.*термин", "систем.*орган",
      # ZH / JA / PL
      "不良事件", "严重不良", "有害事象", "niepożąd",
      sep = "|"
    ),
    DM = paste(
      "demograph", "demographic", "baseline character",
      "demografía", "demografia", "demograf",
      "демограф", "исходн.*характерист",
      "人口学", "人口統計", "人口统计学",
      "demographie", "demografie",
      sep = "|"
    ),
    VS = paste(
      "vital sign", "blood pressure", "heart rate", "\\bpulse\\b",
      "respiratory rate",
      "vitalparameter", "vitalzeichen",
      "signes vitaux", "signos vitales",
      "витальн", "жизненн.*показател", "артериальн.*давлен", "пульс",
      "血压", "脉搏", "バイタル",
      sep = "|"
    ),
    LB = paste(
      "\\blab(?:oratory)?\\b", "chemistry", "hematology", "haematology",
      "hy.?s law", "liver enzyme",
      "laborwert", "laborbefund", "laboratoire", "laboratorio",
      "лаборатор", "биохим", "гематолог",
      "实验室", "检验", "臨床検査",
      sep = "|"
    ),
    EFFC = paste(
      "efficac", "endpoint", "primary analysis", "adas", "cibic", "\\bnpi\\b",
      "\\bmmse\\b", "\\bcdr\\b", "scale score",
      "wirksamkeit", "efficacité", "eficacia", "efficacia",
      "эффективност", "конечн.*точк", "первичн.*конечн",
      "疗效", "有效性", "有効性",
      sep = "|"
    ),
    EX = paste(
      "exposure", "cumulative dose", "drug administration",
      "exposit", "posolog",
      "экспозиц", "дозиров", "приверженност",
      "暴露", "给药",
      sep = "|"
    ),
    DS = paste(
      "disposition", "discontinu", "withdrawal", "end of study",
      "analysis set", "intent.?to.?treat", "\\bitt\\b",
      "safety population",
      "выбыван", "исключен", "популац", "анализ.*набор",
      "受试者分布", "中止",
      sep = "|"
    )
  )
}

#' @keywords internal
#' @noRd
.capsule_domain_from_lexicon <- function(ctx) {
  txt <- paste(
    paste(ctx$title %||% character(), collapse = " "),
    paste(ctx$subtitles %||% character(), collapse = " "),
    ctx$source %||% "",
    sep = " "
  )
  # Keep original script; case-fold only Latin via tolower for EN/DE/FR/ES…
  tx <- tolower(txt)
  lex <- .capsule_domain_lexicon()
  # Prefer more specific clinical domains before broad ones.
  order <- c("AE", "LB", "VS", "EFFC", "EX", "DM", "DS")
  for (dom in order) {
    pat <- lex[[dom]]
    if (is.null(pat)) next
    hit <- tryCatch(
      grepl(pat, tx, ignore.case = TRUE, perl = TRUE),
      error = function(e) FALSE
    )
    if (isTRUE(hit)) {
      return(dom)
    }
  }
  NULL
}

#' Infer domain from CSR/ICH-style table numbering in the output id.
#'
#' Language-independent fallback used when titles are non-English and no
#' structural MedDRA markers are present. Matches common CDISC Pilot /
#' ICH E3 section numbering (14-1 disposition, 14-2 demography, 14-3
#' efficacy, 14-4 exposure, 14-5 AE, 14-6 laboratory, 14-7 vital signs).
#'
#' @keywords internal
#' @noRd
.capsule_domain_from_id <- function(id) {
  id <- as.character(id %||% "")
  # Accept "14-5.01", "t-14-5-01", "Table_14_5_01", "14.5.01"
  m <- regmatches(
    id,
    regexpr("(?i)(?:^|[^0-9])14[\\._-]?([1-9])(?:[\\._-]|\\b)", id, perl = TRUE)
  )
  if (!length(m) || !nzchar(m[[1]])) {
    return(NULL)
  }
  digit <- sub("(?i).*14[\\._-]?([1-9]).*", "\\1", m[[1]], perl = TRUE)
  switch(
    digit,
    "1" = "DS",
    "2" = "DM",
    "3" = "EFFC",
    "4" = "EX",
    "5" = "AE",
    "6" = "LB",
    "7" = "VS",
    NULL
  )
}

#' @keywords internal
#' @noRd
.wire_capsule_children <- function(capsules) {
  if (!length(capsules)) return(capsules)
  id_to_children <- stats::setNames(vector("list", length(capsules)), names(capsules))
  for (nm in names(capsules)) {
    p <- capsules[[nm]]$parent_id
    if (!is.null(p) && !is.na(p) && nzchar(p) && p %in% names(capsules)) {
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
.link_capsules_to_text_outputs <- function(capsules,
                                          study,
                                          chat = NULL,
                                          llm_domain = "unknown",
                                          llm_min_confidence = 0.5) {
  if (!length(capsules) || !length(study$texts)) return(capsules)
  txt_map <- lapply(study$texts, function(ctx) {
    .capsule_infer_domain(
      ctx,
      chat = chat,
      llm_domain = llm_domain,
      llm_min_confidence = llm_min_confidence
    )
  })
  txt_ids_by_domain <- split(names(txt_map), unlist(txt_map))
  for (nm in names(capsules)) {
    d <- capsules[[nm]]$domain %||% "UNKNOWN"
    capsules[[nm]]$linked_ids <- as.character(txt_ids_by_domain[[d]] %||% character())
  }
  capsules
}
