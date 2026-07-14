## Tools: ellmer tool wrappers that let the LLM retrieve study details on
## demand in large-study mode. Each tool closes over the study registry so the
## model can navigate the whole set of outputs.

# ---------------------------------------------------------------------------
# Tool implementations (plain functions over a study)
# ---------------------------------------------------------------------------

#' List all outputs in the study
#' @keywords internal
#' @noRd
.tool_list_tables <- function(study) {
  all <- .study_all(study)
  if (length(all) == 0) {
    return("No outputs in study.")
  }
  lines <- vapply(all, function(ctx) {
    title <- if (length(ctx$title)) paste(ctx$title, collapse = " ") else ctx$id
    sprintf("- %s (%s): %s", ctx$id, ctx$type, title)
  }, character(1))
  paste(lines, collapse = "\n")
}

#' Return one output rendered as a human-readable Markdown table
#' @keywords internal
#' @noRd
.tool_get_table_context <- function(study, id) {
  ctx <- study[[id]]
  if (is.null(ctx)) {
    return(sprintf("No output with id '%s'.", id))
  }
  as_markdown(ctx)
}

#' Render the first n data rows of a table as a markdown table
#' @keywords internal
#' @noRd
.tool_get_table_data <- function(study, id, n_rows = 10L) {
  ctx <- study[[id]]
  if (is.null(ctx)) {
    return(sprintf("No output with id '%s'.", id))
  }
  if (length(ctx$rows) == 0) {
    return(sprintf("Output '%s' has no tabular rows.", id))
  }
  n_rows <- min(as.integer(n_rows), length(ctx$rows))
  col_names <- names(ctx$rows[[1]]$cells)

  header <- paste0("| section | ", paste(col_names, collapse = " | "), " |")
  sep <- paste0("|", paste(rep("---", length(col_names) + 1), collapse = "|"), "|")
  body <- vapply(seq_len(n_rows), function(i) {
    row <- ctx$rows[[i]]
    section <- if (is.na(row$section)) "" else row$section
    cells <- vapply(col_names, function(c) {
      v <- row$cells[[c]]
      if (is.null(v) || is.na(v)) "" else as.character(v)
    }, character(1))
    paste0("| ", section, " | ", paste(cells, collapse = " | "), " |")
  }, character(1))

  paste(c(header, sep, body), collapse = "\n")
}

#' Search outputs by keyword across titles, population, and footnotes
#' @keywords internal
#' @noRd
.tool_search_tables <- function(study, keyword) {
  all <- .study_all(study)
  if (length(all) == 0) {
    return("No outputs in study.")
  }
  kw <- tolower(keyword)
  hits <- Filter(function(ctx) {
    hay <- tolower(paste(
      paste(ctx$title, collapse = " "),
      ctx$population,
      paste(ctx$footnotes, collapse = " "),
      collapse = " "
    ))
    grepl(kw, hay, fixed = TRUE)
  }, all)
  if (length(hits) == 0) {
    return(sprintf("No outputs match '%s'.", keyword))
  }
  lines <- vapply(hits, function(ctx) {
    title <- if (length(ctx$title)) paste(ctx$title, collapse = " ") else ctx$id
    sprintf("- %s: %s", ctx$id, title)
  }, character(1))
  paste(lines, collapse = "\n")
}

#' Structurally compare two outputs
#' @keywords internal
#' @noRd
.tool_compare_tables <- function(study, id1, id2) {
  a <- study[[id1]]
  b <- study[[id2]]
  if (is.null(a)) return(sprintf("No output with id '%s'.", id1))
  if (is.null(b)) return(sprintf("No output with id '%s'.", id2))

  cols_a <- vapply(a$columns, function(c) c$label %||% c$name, character(1))
  cols_b <- vapply(b$columns, function(c) c$label %||% c$name, character(1))

  fmt_list <- function(x) if (length(x)) paste(x, collapse = ", ") else "(none)"

  paste(
    sprintf("Comparison of %s vs %s:", id1, id2),
    sprintf("- Population: %s vs %s", a$population, b$population),
    sprintf("- Type: %s vs %s", a$type, b$type),
    sprintf("- Rows: %d vs %d", a$n_rows_total, b$n_rows_total),
    sprintf("- Columns (%s): %s", id1, fmt_list(cols_a)),
    sprintf("- Columns (%s): %s", id2, fmt_list(cols_b)),
    sprintf("- Shared columns: %s", fmt_list(intersect(cols_a, cols_b))),
    sep = "\n"
  )
}

#' Return the compact study index
#' @keywords internal
#' @noRd
.tool_get_study_index <- function(study) {
  .build_compact_index(study)
}

# ---------------------------------------------------------------------------
# Registration
# ---------------------------------------------------------------------------

#' Register the study-navigation tools on a kschat's ellmer chat
#'
#' @param ks A `kschat` object.
#' @return Invisibly, `ks`.
#' @keywords internal
#' @noRd
.register_tools <- function(ks) {
  study <- ks$study
  chat <- ks$chat

  chat$register_tool(ellmer::tool(
    function() .tool_list_tables(study),
    name = "list_tables",
    description = "List every output (table/figure) in the study with its id, type, and title."
  ))

  chat$register_tool(ellmer::tool(
    function(id) .tool_get_table_context(study, id),
    name = "get_table_context",
    description = paste(
      "Get one output rendered as a human-readable Markdown table (title,",
      "population, treatment-arm columns, section-grouped rows, footnotes).",
      "Use this to read a table's contents."
    ),
    arguments = list(
      id = ellmer::type_string("The output id, e.g. '14-3.01'.")
    )
  ))

  chat$register_tool(ellmer::tool(
    function(id, n_rows = 10L) .tool_get_table_data(study, id, n_rows),
    name = "get_table_data",
    description = "Return the first n rows of an output's data as a markdown table.",
    arguments = list(
      id = ellmer::type_string("The output id, e.g. '14-3.01'."),
      n_rows = ellmer::type_integer("Number of rows to return (default 10).", required = FALSE)
    )
  ))

  chat$register_tool(ellmer::tool(
    function(keyword) .tool_search_tables(study, keyword),
    name = "search_tables",
    description = "Find outputs whose title, population, or footnotes contain a keyword.",
    arguments = list(
      keyword = ellmer::type_string("The search keyword, e.g. 'vital signs' or 'ADAS'.")
    )
  ))

  chat$register_tool(ellmer::tool(
    function(id1, id2) .tool_compare_tables(study, id1, id2),
    name = "compare_tables",
    description = "Structurally compare two outputs (population, columns, row counts).",
    arguments = list(
      id1 = ellmer::type_string("First output id."),
      id2 = ellmer::type_string("Second output id.")
    )
  ))

  chat$register_tool(ellmer::tool(
    function() .tool_get_study_index(study),
    name = "get_study_index",
    description = "Return a compact index of all study outputs as a markdown table."
  ))

  invisible(ks)
}
