## ks_result: persisted outputs of ks_llm() runs.

#' Construct a ks_result object
#' @keywords internal
#' @noRd
new_ks_result <- function(ids,
                          skill = NULL,
                          prompt = NULL,
                          response,
                          model,
                          provider,
                          timestamp = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")) {
  checkmate::assert_character(ids, min.len = 1, any.missing = FALSE)
  checkmate::assert_string(skill, null.ok = TRUE)
  checkmate::assert_string(prompt, null.ok = TRUE)
  checkmate::assert_string(response)
  checkmate::assert_string(model)
  checkmate::assert_string(provider)
  checkmate::assert_string(timestamp)

  structure(
    list(
      ids = ids,
      skill = skill,
      prompt = prompt,
      response = response,
      model = model,
      provider = provider,
      timestamp = timestamp
    ),
    class = c("ks_result", "list")
  )
}

#' The ks_result Class
#'
#' A `ks_result` stores one generated answer from [ks_llm()], including the
#' selected output ids, prompt metadata, model/provider, and response text.
#' `is_ks_result()` tests for the class.
#'
#' @param x An object.
#' @return `TRUE` if `x` is a `ks_result`, otherwise `FALSE`.
#' @aliases ks_result
#' @export
is_ks_result <- function(x) {
  inherits(x, "ks_result")
}

#' @export
print.ks_result <- function(x, ...) {
  cli::cli_h1("ks_result")
  cli::cli_text("{.strong IDs}: {paste(x$ids, collapse = ', ')}")
  cli::cli_text("{.strong Skill}: {x$skill %||% '(none)'}")
  cli::cli_text("{.strong Model}: {x$model} ({x$provider})")
  cli::cli_text("{.strong Timestamp}: {x$timestamp}")

  preview <- x$response
  if (nchar(preview) > 300) {
    preview <- paste0(substr(preview, 1, 300), "...")
  }
  cli::cli_h2("Response Preview")
  cli::cli_text(preview)
  invisible(x)
}

#' Persist a ks_result as Markdown and JSON
#'
#' Writes both a human-readable Markdown file and a machine-readable JSON file.
#'
#' @param result A [ks_result] object.
#' @param path Character scalar. Output path base or path ending in `.md`/`.json`.
#'
#' @return Invisibly, a list with `md` and `json` output paths.
#' @export
save_result <- function(result, path) {
  if (!is_ks_result(result)) {
    cli::cli_abort("{.arg result} must be a {.cls ks_result} object.")
  }
  checkmate::assert_string(path)

  ext <- tolower(tools::file_ext(path))
  base <- if (ext %in% c("md", "json")) {
    sub(paste0("\\.", ext, "$"), "", path)
  } else {
    path
  }

  md_path <- paste0(base, ".md")
  json_path <- paste0(base, ".json")

  md_lines <- c(
    "# ksAI result",
    "",
    paste0("- ids: ", paste(result$ids, collapse = ", ")),
    paste0("- skill: ", result$skill %||% ""),
    paste0("- model: ", result$model),
    paste0("- provider: ", result$provider),
    paste0("- timestamp: ", result$timestamp),
    "",
    "## Response",
    "",
    result$response
  )
  writeLines(md_lines, con = md_path)

  payload <- unclass(result)
  json <- jsonlite::toJSON(payload, auto_unbox = TRUE, null = "null", digits = NA, pretty = TRUE)
  writeLines(json, con = json_path)

  invisible(list(md = md_path, json = json_path))
}

#' Load a saved ks_result
#'
#' Loads a previously saved result. If both `.md` and `.json` exist, JSON is
#' used as the canonical source.
#'
#' @param path Character scalar. Base path or `.md`/`.json` file path.
#'
#' @return A [ks_result] object.
#' @export
load_result <- function(path) {
  checkmate::assert_string(path)

  ext <- tolower(tools::file_ext(path))
  if (ext == "json") {
    json_path <- path
    md_path <- sub("\\.json$", ".md", path)
  } else if (ext == "md") {
    md_path <- path
    json_path <- sub("\\.md$", ".json", path)
  } else {
    json_path <- paste0(path, ".json")
    md_path <- paste0(path, ".md")
  }

  if (file.exists(json_path)) {
    payload <- tryCatch(
      jsonlite::fromJSON(json_path, simplifyVector = FALSE),
      error = function(e) NULL
    )
    if (is.null(payload)) {
      cli::cli_abort("Could not parse result file {.path {json_path}}.")
    }
    ids <- as.character(unlist(payload$ids) %||% character())
    skill <- if (is.null(payload$skill)) NULL else as.character(payload$skill)
    prompt <- if (is.null(payload$prompt)) NULL else as.character(payload$prompt)
    response <- as.character(payload$response %||% "")
    model <- as.character(payload$model %||% "")
    provider <- as.character(payload$provider %||% "")
    timestamp <- as.character(payload$timestamp %||% "")

    return(new_ks_result(
      ids = ids,
      skill = skill,
      prompt = prompt,
      response = response,
      model = model,
      provider = provider,
      timestamp = timestamp
    ))
  }

  if (!file.exists(md_path)) {
    cli::cli_abort("Result file not found at {.path {path}}.")
  }

  lines <- readLines(md_path, warn = FALSE, encoding = "UTF-8")
  keys <- c("ids", "skill", "model", "provider", "timestamp")
  vals <- stats::setNames(as.list(rep("", length(keys))), keys)

  for (key in keys) {
    match <- grep(paste0("^- ", key, ":\\s*"), lines)
    if (length(match)) {
      vals[[key]] <- sub(paste0("^- ", key, ":\\s*"), "", lines[[match[[1]]]])
    }
  }

  marker <- grep("^## Response\\s*$", lines)
  response <- ""
  if (length(marker)) {
    start <- marker[[1]] + 1L
    while (start <= length(lines) && identical(lines[[start]], "")) {
      start <- start + 1L
    }
    if (start <= length(lines)) {
      response <- paste(lines[start:length(lines)], collapse = "\n")
    }
  }

  ids <- trimws(unlist(strsplit(vals$ids, ",", fixed = TRUE)))
  ids <- ids[nzchar(ids)]
  if (!length(ids)) {
    cli::cli_abort("Could not read output IDs from {.path {md_path}}.")
  }

  new_ks_result(
    ids = ids,
    skill = if (nzchar(vals$skill)) vals$skill else NULL,
    prompt = NULL,
    response = response,
    model = vals$model,
    provider = vals$provider,
    timestamp = vals$timestamp
  )
}
