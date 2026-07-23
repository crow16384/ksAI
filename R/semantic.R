## Semantic agent: annotate capsules with concepts/keywords/synonyms.

#' Annotate Capsule Store with Semantic Metadata
#'
#' Enriches capsules in a [ks_capsule_store] in two passes: a deterministic
#' token/abbreviation pass, plus an optional small-LLM extraction pass.
#' When `model` is supplied, capsules still tagged `UNKNOWN` are also
#' reclassified once per `source_id` by the same small model (closed domain
#' codes). Use `force_domain = TRUE` to reclassify every source table.
#'
#' @param store A `ks_capsule_store`.
#' @param model Optional model for the small semantic LLM pass (and domain
#'   fallback).
#' @param provider Provider for LLM pass. Defaults to [ks_get_option()]`provider`.
#' @param base_url Optional provider URL override.
#' @param batch_size Integer batch size for deterministic pass.
#' @param force Recompute keyword/concept metadata even if already present.
#' @param force_domain Reclassify domains with the LLM even when not
#'   `UNKNOWN`. Ignored when `model` is `NULL`.
#' @param llm_min_confidence Minimum confidence (0–1) to accept an LLM domain.
#' @param ... Extra args forwarded to the chat constructor.
#'
#' @return Updated `ks_capsule_store`.
#' @export
ks_annotate <- function(store,
                        model = NULL,
                        provider = ks_get_option("provider"),
                        base_url = NULL,
                        batch_size = 64L,
                        force = FALSE,
                        force_domain = FALSE,
                        llm_min_confidence = 0.5,
                        ...) {
  if (!is_ks_capsule_store(store)) {
    cli::cli_abort("{.arg store} must be a {.cls ks_capsule_store} object.")
  }
  checkmate::assert_int(batch_size, lower = 1L)
  checkmate::assert_flag(force)
  checkmate::assert_flag(force_domain)
  checkmate::assert_number(llm_min_confidence, lower = 0, upper = 1)
  dots <- rlang::list2(...)

  if (!length(store$capsules)) {
    return(store)
  }

  ids <- names(store$capsules)
  for (start in seq.int(1L, length(ids), by = batch_size)) {
    end <- min(length(ids), start + batch_size - 1L)
    for (cid in ids[start:end]) {
      cap <- store$capsules[[cid]]
      if (!force && (length(cap$concepts) > 0 || length(cap$keywords) > 0)) {
        next
      }
      seed <- .extract_keywords_r(cap)
      cap$keywords <- unique(c(cap$keywords, seed$keywords))
      cap$synonyms <- unique(c(cap$synonyms, seed$synonyms))
      if (!length(cap$concepts)) {
        cap$concepts <- seed$concepts
      }
      store$capsules[[cid]] <- cap
    }
  }

  if (!is.null(model) && nzchar(model)) {
    store <- .annotate_llm(
      store = store,
      model = model,
      provider = provider,
      base_url = base_url,
      force = force,
      dots = dots
    )
    store <- .annotate_domains_llm(
      store = store,
      model = model,
      provider = provider,
      base_url = base_url,
      force_domain = force_domain,
      min_confidence = llm_min_confidence,
      dots = dots
    )
  }

  store
}

#' @keywords internal
#' @noRd
.extract_keywords_r <- function(capsule) {
  txt <- paste(
    capsule$label %||% "",
    capsule$compact_text %||% "",
    paste(capsule$concepts %||% character(), collapse = " "),
    sep = " "
  )
  tokens <- tolower(unlist(strsplit(gsub("[^A-Za-z0-9]+", " ", txt), "\\s+")))
  tokens <- tokens[nzchar(tokens)]
  stop <- c("the", "and", "for", "with", "from", "table", "population", "values")
  keywords <- unique(tokens[!tokens %in% stop])

  syn_map <- list(
    soc = c("system organ class"),
    pt = c("preferred term"),
    teae = c("treatment emergent adverse event", "adverse event"),
    dm = c("demographics"),
    vs = c("vital signs"),
    lb = c("laboratory")
  )
  synonyms <- unique(unlist(syn_map[intersect(names(syn_map), keywords)], use.names = FALSE))
  concepts <- unique(c(capsule$label %||% "", synonyms))
  list(
    concepts = concepts[nzchar(concepts)],
    keywords = keywords,
    synonyms = synonyms
  )
}

#' @keywords internal
#' @noRd
.annotate_llm <- function(store, model, provider, base_url, force = FALSE, dots = list()) {
  system_prompt <- paste(
    "You are a clinical semantic extraction model.",
    "Return strict JSON with keys: concepts, synonyms, keywords.",
    "Each key must map to an array of short strings.",
    sep = " "
  )
  chat <- rlang::exec(
    .make_ellmer_chat,
    provider = provider,
    model = model,
    system_prompt = system_prompt,
    base_url = base_url,
    echo = "none",
    !!!dots
  )

  for (cid in names(store$capsules)) {
    cap <- store$capsules[[cid]]
    if (!force && length(cap$concepts) > 0 && length(cap$keywords) > 0) {
      next
    }
    req <- paste(
      "Given this clinical summary, return JSON with keys concepts, synonyms, keywords.",
      "Summary:",
      cap$compact_text %||% cap$label %||% "",
      sep = "\n\n"
    )
    out <- tryCatch(as.character(chat$chat(req)), error = function(e) NULL)
    if (is.null(out) || !nzchar(out)) {
      next
    }
    parsed <- tryCatch(jsonlite::fromJSON(out, simplifyVector = TRUE), error = function(e) NULL)
    if (is.null(parsed)) {
      json_block <- regmatches(out, regexpr("\\{[\\s\\S]*\\}", out, perl = TRUE))
      if (length(json_block) == 1L && nzchar(json_block[[1]])) {
        parsed <- tryCatch(jsonlite::fromJSON(json_block[[1]], simplifyVector = TRUE), error = function(e) NULL)
      }
    }
    if (is.null(parsed)) next

    cap$concepts <- unique(c(cap$concepts, as.character(unlist(parsed$concepts) %||% character())))
    cap$synonyms <- unique(c(cap$synonyms, as.character(unlist(parsed$synonyms) %||% character())))
    cap$keywords <- unique(c(cap$keywords, as.character(unlist(parsed$keywords) %||% character())))
    store$capsules[[cid]] <- cap
  }
  store
}

#' Reclassify capsule domains with a small LLM (once per source_id).
#'
#' @keywords internal
#' @noRd
.annotate_domains_llm <- function(store,
                                  model,
                                  provider,
                                  base_url,
                                  force_domain = FALSE,
                                  min_confidence = 0.5,
                                  dots = list()) {
  chat <- .make_domain_llm_chat(
    model = model,
    provider = provider,
    base_url = base_url,
    llm_domain = "unknown",
    dots = dots
  )
  if (is.null(chat)) {
    return(store)
  }

  by_src <- split(
    names(store$capsules),
    vapply(store$capsules, function(c) as.character(c$source_id %||% ""), character(1))
  )

  for (sid in names(by_src)) {
    if (!nzchar(sid)) next
    cids <- by_src[[sid]]
    domains <- unique(vapply(
      store$capsules[cids],
      function(c) as.character(c$domain %||% "UNKNOWN"),
      character(1)
    ))
    if (!force_domain && !all(domains == "UNKNOWN")) {
      next
    }

    caps <- store$capsules[cids]
    overall <- Filter(function(c) identical(c$level, "OVERALL"), caps)
    seed <- if (length(overall)) overall[[1]] else caps[[1]]
    sample_caps <- caps[seq_len(min(8L, length(caps)))]
    synth <- new_ks_context(
      id = sid,
      type = "Table",
      title = c(seed$label %||% sid),
      population = seed$population %||% NA_character_,
      rows = lapply(sample_caps, function(c) {
        list(kind = c$level %||% "", cells = list(c$label %||% ""))
      }),
      n_rows_total = length(cids),
      footnotes = as.character(seed$compact_text %||% "")
    )
    # Fold compact summary into the prompt via source field.
    synth$source <- as.character(seed$compact_text %||% "")

    hit <- .capsule_domain_from_llm(synth, chat, min_confidence)
    if (is.null(hit) || identical(hit, "UNKNOWN")) {
      next
    }
    for (cid in cids) {
      store$capsules[[cid]]$domain <- hit
    }
  }
  store
}
