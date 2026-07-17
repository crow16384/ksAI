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
#' @param x A `ks_context` or `ks_study`.
#' @param ... Unused; for S3 compatibility.
#'
#' @return A `ks_capsule_store`.
#' @export
as_capsules <- function(x, ...) {
  UseMethod("as_capsules")
}

#' @export
as_capsules.ks_context <- function(x, ...) {
  if (!length(x$rows)) {
    return(new_ks_capsule_store(capsules = list()))
  }

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
    .capsule_from_group(x, g, row_label_col, capsule_id = ids[[i]], parent_id = parent_ids[[i]])
  })
  names(capsules) <- vapply(capsules, function(c) c$capsule_id, character(1))
  capsules <- .wire_capsule_children(capsules)
  new_ks_capsule_store(capsules = capsules)
}

#' @export
as_capsules.ks_study <- function(x, ...) {
  all <- .study_all(x)
  if (!length(all)) {
    return(new_ks_capsule_store(capsules = list(), meta_dir = x$meta_dir))
  }
  pieces <- lapply(all, as_capsules)
  caps <- Reduce(c, lapply(pieces, function(s) s$capsules))
  caps <- .link_capsules_to_text_outputs(caps, x)
  new_ks_capsule_store(
    capsules = caps,
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
.capsule_from_group <- function(ctx, g, row_label_col, capsule_id, parent_id) {
  idx <- g$idx
  row <- ctx$rows[[idx]]
  source_rows <- as.integer(g$rows %||% idx)
  label <- if (nzchar(g$label)) g$label else paste0("ROW_", idx)
  stats <- .capsule_extract_stats(row$cells, row_label_col, ctx$span_headers)
  compact_text <- .capsule_compact_for_rows(ctx, source_rows)
  new_ks_capsule(
    capsule_id = capsule_id,
    source_id = ctx$id,
    source_rows = source_rows,
    domain = .capsule_infer_domain(ctx),
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

#' @keywords internal
#' @noRd
.capsule_infer_domain <- function(ctx) {
  txt <- paste(
    paste(ctx$title %||% character(), collapse = " "),
    ctx$source %||% "",
    sep = " "
  )
  tx <- tolower(txt)
  if (grepl("adverse|teae|serious", tx)) return("AE")
  if (grepl("demograph|baseline", tx)) return("DM")
  if (grepl("vital", tx)) return("VS")
  if (grepl("lab|chemistry|hematology", tx)) return("LB")
  if (grepl("efficacy|adas|cibic|npi", tx)) return("EFFC")
  "UNKNOWN"
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
.link_capsules_to_text_outputs <- function(capsules, study) {
  if (!length(capsules) || !length(study$texts)) return(capsules)
  txt_map <- lapply(study$texts, .capsule_infer_domain)
  txt_ids_by_domain <- split(names(txt_map), unlist(txt_map))
  for (nm in names(capsules)) {
    d <- capsules[[nm]]$domain %||% "UNKNOWN"
    capsules[[nm]]$linked_ids <- as.character(txt_ids_by_domain[[d]] %||% character())
  }
  capsules
}
