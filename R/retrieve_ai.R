## Retrieval agent over capsules.

#' Retrieve Relevant Clinical Capsules
#'
#' Scores capsules against a query using embedding similarity, keyword overlap,
#' and metadata matching, then returns the top-ranked subset.
#'
#' @param store A `ks_capsule_store`.
#' @param query User question or retrieval query.
#' @param n Maximum number of capsules to return.
#' @param filter Optional named list with any of: `label`, `population`,
#'   `member_id` (output id that must be among capsule members).
#' @param weights Named numeric list with `semantic`, `keyword`, `metadata`.
#' @param model Embedding model for query embedding.
#' @param base_url Embedding endpoint base URL.
#'
#' @return A `ks_capsule_subset`.
#' @export
ks_retrieve <- function(store,
                        query,
                        n = 5L,
                        filter = list(),
                        weights = list(semantic = 0.6, keyword = 0.3, metadata = 0.1),
                        model = ks_get_option("embed_model"),
                        base_url = ks_get_option("embed_url")) {
  if (!is_ks_capsule_store(store)) {
    cli::cli_abort("{.arg store} must be a {.cls ks_capsule_store} object.")
  }
  checkmate::assert_string(query)
  checkmate::assert_int(n, lower = 1L)
  checkmate::assert_list(filter, names = "named", null.ok = TRUE)
  if (!length(store$capsules)) {
    return(new_ks_capsule_subset(list(), data.frame(), query = query))
  }
  w <- .normalize_weights(weights)
  query_tokens <- .tokens(query)
  q_embed <- tryCatch(.embed_text(query, model = model, base_url = base_url), error = function(e) NULL)
  scored <- .score_capsules(store$capsules, query_tokens, q_embed, filter, w)
  ord <- order(scored$score, decreasing = TRUE, na.last = TRUE)
  top <- head(ord, n)
  caps <- store$capsules[scored$capsule_id[top]]
  new_ks_capsule_subset(capsules = caps, scores = scored[top, , drop = FALSE], query = query)
}

#' @keywords internal
#' @noRd
new_ks_capsule_subset <- function(capsules, scores, query) {
  structure(
    list(capsules = capsules, scores = scores, query = query),
    class = c("ks_capsule_subset", "list")
  )
}

#' @export
print.ks_capsule_subset <- function(x, ...) {
  cli::cli_h1("ks_capsule_subset")
  cli::cli_text("{.strong Query}: {x$query}")
  cli::cli_text("{.strong Capsules}: {length(x$capsules)}")
  if (NROW(x$scores)) {
    top <- utils::head(x$scores[order(x$scores$score, decreasing = TRUE), c("capsule_id", "score")], 5)
    for (i in seq_len(NROW(top))) {
      cli::cli_li("{top$capsule_id[[i]]}: {sprintf('%.3f', top$score[[i]])}")
    }
  }
  invisible(x)
}

#' @keywords internal
#' @noRd
.normalize_weights <- function(w) {
  defaults <- c(semantic = 0.6, keyword = 0.3, metadata = 0.1)
  if (is.null(names(w))) return(defaults)
  defaults[names(w)] <- as.numeric(unlist(w))
  s <- sum(defaults)
  if (s <= 0) return(c(semantic = 1, keyword = 0, metadata = 0))
  defaults / s
}

#' @keywords internal
#' @noRd
.tokens <- function(x) {
  t <- tolower(unlist(strsplit(gsub("[^A-Za-z0-9]+", " ", x), "\\s+")))
  unique(t[nzchar(t)])
}

#' @keywords internal
#' @noRd
.score_capsules <- function(capsules, query_tokens, q_embed, filter, w) {
  rows <- lapply(names(capsules), function(cid) {
    cap <- capsules[[cid]]
    txt_tokens <- .tokens(paste(cap$keywords %||% character(), cap$label %||% "", sep = " "))
    keyword <- if (length(query_tokens)) {
      length(intersect(query_tokens, txt_tokens)) / max(1L, length(unique(query_tokens)))
    } else {
      0
    }
    semantic <- if (!is.null(q_embed) && !is.null(cap$embedding)) .cosine_sim(q_embed, cap$embedding) else NA_real_
    if (is.na(semantic)) semantic <- 0

    meta <- 0
    checks <- 0
    if (!is.null(filter$label)) {
      checks <- checks + 1
      if (grepl(as.character(filter$label), as.character(cap$label %||% ""), ignore.case = TRUE, fixed = TRUE) ||
          identical(as.character(filter$label), as.character(cap$label))) {
        meta <- meta + 1
      }
    }
    if (!is.null(filter$member_id)) {
      checks <- checks + 1
      if (as.character(filter$member_id) %in% as.character(cap$member_ids %||% character())) {
        meta <- meta + 1
      }
    }
    if (!is.null(filter$population)) {
      checks <- checks + 1
      if (identical(as.character(filter$population), as.character(cap$population))) meta <- meta + 1
    }
    metadata <- if (checks > 0) meta / checks else 0
    score <- w[["semantic"]] * semantic + w[["keyword"]] * keyword + w[["metadata"]] * metadata
    data.frame(
      capsule_id = cid,
      semantic = semantic,
      keyword = keyword,
      metadata = metadata,
      score = score,
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}
