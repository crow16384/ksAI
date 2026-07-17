## Embedding helper for capsule semantic search.

#' Embed Capsule Texts
#'
#' Calls an OpenAI-compatible embeddings endpoint (e.g., LM Studio) for each
#' capsule's compact text and stores numeric vectors in `capsule$embedding`.
#'
#' @param store A `ks_capsule_store`.
#' @param model Embedding model name.
#' @param base_url Embedding endpoint base URL.
#' @param force Re-embed capsules even if an embedding already exists.
#'
#' @return Updated `ks_capsule_store`.
#' @export
ks_embed <- function(store,
                     model = ks_get_option("embed_model"),
                     base_url = ks_get_option("embed_url"),
                     force = FALSE) {
  if (!is_ks_capsule_store(store)) {
    cli::cli_abort("{.arg store} must be a {.cls ks_capsule_store} object.")
  }
  checkmate::assert_string(model)
  checkmate::assert_string(base_url)
  checkmate::assert_flag(force)

  for (cid in names(store$capsules)) {
    cap <- store$capsules[[cid]]
    if (!force && !is.null(cap$embedding)) {
      next
    }
    txt <- cap$compact_text %||% cap$label %||% ""
    emb <- tryCatch(.embed_text(txt, model = model, base_url = base_url), error = function(e) NULL)
    if (is.null(emb)) next
    cap$embedding <- emb
    store$capsules[[cid]] <- cap
  }
  store
}

#' @keywords internal
#' @noRd
.embed_text <- function(text, model, base_url) {
  req <- httr2::request(paste0(sub("/$", "", base_url), "/embeddings")) |>
    httr2::req_method("POST") |>
    httr2::req_headers(`Content-Type` = "application/json") |>
    httr2::req_body_json(list(model = model, input = text), auto_unbox = TRUE)
  resp <- httr2::req_perform(req)
  payload <- httr2::resp_body_json(resp, simplifyVector = FALSE)
  emb <- payload$data[[1]]$embedding %||% NULL
  if (is.null(emb)) {
    cli::cli_abort("Embedding endpoint returned no embedding vector.")
  }
  as.numeric(unlist(emb))
}

#' @keywords internal
#' @noRd
.cosine_sim <- function(a, b) {
  if (!length(a) || !length(b) || length(a) != length(b)) {
    return(NA_real_)
  }
  na <- sqrt(sum(a * a))
  nb <- sqrt(sum(b * b))
  if (na == 0 || nb == 0) return(NA_real_)
  sum(a * b) / (na * nb)
}
