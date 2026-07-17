## ks_facts: columnar fact store built from ks_context for structured retrieval.
##
## Wraps a C++23 FactTable + InvertedIndex (via Rcpp XPtr). Build with
## as_facts(), filter with retrieve(), render with as_compact().

# ---------------------------------------------------------------------------
# Constructor / predicates
# ---------------------------------------------------------------------------

#' @keywords internal
#' @noRd
new_ks_facts <- function(ptr,
                         id,
                         meta,
                         schema,
                         span_map = list(),
                         col_labels = character(),
                         measure_filter = NULL) {
  structure(
    list(
      ptr = ptr,
      id = id,
      meta = meta,
      schema = schema,
      span_map = span_map,
      col_labels = col_labels,
      measure_filter = measure_filter
    ),
    class = c("ks_facts", "list")
  )
}

#' The `ks_facts` Class
#'
#' A compact, retrieval-capable representation of one [ks_context]'s rows.
#' Build with [as_facts()], subset with [retrieve()], render with
#' [as_compact()].
#'
#' @param x An object.
#' @return `TRUE` if `x` is a `ks_facts`, otherwise `FALSE`.
#' @export
is_ks_facts <- function(x) {
  inherits(x, "ks_facts")
}

#' @export
print.ks_facts <- function(x, ...) {
  n <- tryCatch(ks_get_dictionaries(x$ptr)$n_rows, error = function(e) NA_integer_)
  cli::cli_h1("ks_facts: {x$id}")
  if (length(x$meta$title)) {
    cli::cli_text("{.strong Title}: {paste(x$meta$title, collapse = ' \u2014 ')}")
  }
  if (!is.null(x$meta$population) && !is.na(x$meta$population)) {
    cli::cli_text("{.strong Population}: {x$meta$population}")
  }
  cli::cli_text("{.strong Rows}: {n}")
  cli::cli_text(
    "{.strong Schema}: row_label={x$schema$row_label}; dims={length(x$schema$dim_names)}; measures={length(x$schema$measure_names)}"
  )
  if (!is.null(x$measure_filter)) {
    cli::cli_text("{.strong Measure filter}: {paste(x$measure_filter, collapse = ', ')}")
  }
  invisible(x)
}

# ---------------------------------------------------------------------------
# Column classification & packing
# ---------------------------------------------------------------------------

#' Classify visible ks_context columns into row_label / dims / measures
#' @keywords internal
#' @noRd
.classify_columns <- function(columns) {
  if (length(columns) == 0) {
    return(list(
      row_label = NA_character_,
      dim_names = character(),
      measure_names = character()
    ))
  }
  nms <- vapply(columns, function(c) c$name, character(1))
  row_label <- nms[[1]]
  if (length(columns) == 1L) {
    return(list(
      row_label = row_label,
      dim_names = character(),
      measure_names = character()
    ))
  }
  rest_cols <- columns[-1]
  rest_nms <- nms[-1]
  is_dim <- vapply(rest_cols, function(c) isTRUE(c$is_grouping), logical(1))
  list(
    row_label = row_label,
    dim_names = unname(rest_nms[is_dim]),
    measure_names = unname(rest_nms[!is_dim])
  )
}

#' Pack ks_context rows for C++ FactTable builder
#' @keywords internal
#' @noRd
.rows_to_list <- function(rows, schema) {
  rl <- schema$row_label
  dims <- schema$dim_names
  measures <- schema$measure_names

  lapply(rows, function(row) {
    cells <- row$cells %||% list()
    dim_vals <- lapply(dims, function(nm) {
      v <- cells[[nm]]
      if (is.null(v) || (length(v) == 1 && is.na(v))) "" else as.character(v)
    })
    names(dim_vals) <- dims

    measure_vals <- lapply(measures, function(nm) {
      v <- cells[[nm]]
      if (is.null(v) || (length(v) == 1 && is.na(v))) "" else as.character(v)
    })
    names(measure_vals) <- measures

    label <- cells[[rl]]
    if (is.null(label) || (length(label) == 1 && is.na(label))) {
      label <- ""
    } else {
      label <- as.character(label)
    }

    sec <- row$section
    if (is.null(sec) || (length(sec) == 1 && is.na(sec))) sec <- ""
    kind <- row$kind
    if (is.null(kind) || (length(kind) == 1 && is.na(kind))) kind <- ""

    list(
      row_label = label,
      section = as.character(sec),
      kind = as.character(kind),
      dims = dim_vals,
      measures = measure_vals
    )
  })
}

#' Map span_headers to span_label -> column ids
#' @keywords internal
#' @noRd
.extract_span_map <- function(x) {
  if (!length(x$span_headers)) {
    return(list())
  }
  out <- lapply(x$span_headers, function(s) as.character(s$cols %||% character()))
  names(out) <- vapply(x$span_headers, function(s) s$label %||% "", character(1))
  out
}

#' Named character vector of column name -> display label
#' @keywords internal
#' @noRd
.extract_col_labels <- function(columns, schema = NULL) {
  if (!length(columns)) {
    return(character())
  }
  nms <- vapply(columns, function(c) c$name, character(1))
  labs <- vapply(columns, function(c) {
    lab <- c$label
    if (is.null(lab) || !nzchar(lab)) c$name else lab
  }, character(1))
  stats::setNames(labs, nms)
}

# ---------------------------------------------------------------------------
# as_facts
# ---------------------------------------------------------------------------

#' Convert a `ks_context` into a Retrievable Fact Store
#'
#' Builds a C++-backed columnar fact table from a compiled [ks_context],
#' enabling structured filtering via [retrieve()] and compact rendering via
#' [as_compact()].
#'
#' @param x A `ks_context` object.
#' @param ... Unused; for S3 compatibility.
#'
#' @return A `ks_facts` object.
#' @export
as_facts <- function(x, ...) {
  UseMethod("as_facts")
}

#' @export
as_facts.ks_context <- function(x, ...) {
  schema <- .classify_columns(x$columns)
  if (is.na(schema$row_label) || !nzchar(schema$row_label)) {
    cli::cli_abort("Cannot build facts: {.cls ks_context} has no visible columns.")
  }
  packed <- .rows_to_list(x$rows, schema)
  schema_cpp <- list(
    dim_names = schema$dim_names,
    measure_names = schema$measure_names
  )
  ptr <- ks_build_fact_table(packed, schema_cpp)
  new_ks_facts(
    ptr = ptr,
    id = x$id,
    meta = list(
      title = x$title,
      subtitles = x$subtitles %||% character(),
      population = x$population,
      footnotes = x$footnotes,
      type = x$type
    ),
    schema = schema,
    span_map = .extract_span_map(x),
    col_labels = .extract_col_labels(x$columns, schema)
  )
}

# ---------------------------------------------------------------------------
# Active measure columns (respecting span filter)
# ---------------------------------------------------------------------------

#' @keywords internal
#' @noRd
.active_measure_names <- function(x) {
  all_m <- x$schema$measure_names
  if (is.null(x$measure_filter)) {
    return(all_m)
  }
  intersect(all_m, x$measure_filter)
}

# ---------------------------------------------------------------------------
# retrieve
# ---------------------------------------------------------------------------

#' Filter a `ks_facts` Store by Row Labels, Sections, or Spans
#'
#' Returns a new `ks_facts` containing only matching rows. Span filters keep
#' measure columns belonging to the named span headers; row and section filters
#' use the C++ inverted index.
#'
#' @param x A `ks_facts` object.
#' @param rows Optional character vector of row-label values to keep.
#' @param sections Optional character vector of section values to keep.
#' @param spans Optional character vector of span-header labels; measure columns
#'   outside those spans are dropped from rendering.
#' @param ... Unused; for S3 compatibility.
#'
#' @return A filtered `ks_facts` object.
#' @export
retrieve <- function(x, ...) {
  UseMethod("retrieve")
}

#' @export
retrieve.ks_facts <- function(x,
                              rows = NULL,
                              sections = NULL,
                              spans = NULL,
                              ...) {
  row_vals <- if (is.null(rows)) character() else as.character(rows)
  sec_vals <- if (is.null(sections)) character() else as.character(sections)

  ptr <- x$ptr
  if (length(row_vals) || length(sec_vals)) {
    ptr <- ks_query_facts(ptr, row_vals, sec_vals)
  }

  measure_filter <- x$measure_filter
  if (!is.null(spans)) {
    spans <- as.character(spans)
    unknown <- setdiff(spans, names(x$span_map))
    if (length(unknown)) {
      cli::cli_abort(c(
        "Unknown span label{?s}: {.val {unknown}}.",
        i = "Available: {.val {names(x$span_map)}}."
      ))
    }
    keep <- unique(unlist(x$span_map[spans], use.names = FALSE))
    # Span maps reference measure (and possibly dim) cols; keep measures only.
    keep <- intersect(keep, x$schema$measure_names)
    if (is.null(measure_filter)) {
      measure_filter <- keep
    } else {
      measure_filter <- intersect(measure_filter, keep)
    }
  }

  new_ks_facts(
    ptr = ptr,
    id = x$id,
    meta = x$meta,
    schema = x$schema,
    span_map = x$span_map,
    col_labels = x$col_labels,
    measure_filter = measure_filter
  )
}

# ---------------------------------------------------------------------------
# as_compact.ks_facts
# ---------------------------------------------------------------------------

#' @export
as_compact.ks_facts <- function(x, ...) {
  # Build a lightweight pseudo-context for shared compact helpers.
  decoded <- ks_decode_facts(x$ptr)
  n <- decoded$n_rows
  measure_names <- .active_measure_names(x)
  dim_names <- x$schema$dim_names
  row_label_col <- x$schema$row_label

  # Column order: row_label, dims, active measures — mirrors ks_context layout.
  col_names <- c(row_label_col, dim_names, measure_names)
  col_labels <- x$col_labels
  missing_labs <- setdiff(col_names, names(col_labels))
  if (length(missing_labs)) {
    col_labels <- c(col_labels, stats::setNames(missing_labs, missing_labs))
  }

  columns <- lapply(col_names, function(nm) {
    list(name = nm, label = unname(col_labels[[nm]] %||% nm), is_grouping = nm %in% dim_names)
  })
  names(columns) <- col_names

  rows <- vector("list", n)
  for (i in seq_len(n)) {
    cells <- list()
    cells[[row_label_col]] <- as.character(decoded$row_label[[i]])
    for (d in dim_names) {
      cells[[d]] <- as.character(decoded$dims[[d]][[i]])
    }
    for (m in measure_names) {
      cells[[m]] <- as.character(decoded$measures[[m]][[i]])
    }
    sec <- decoded$section[[i]]
    kind <- decoded$kind[[i]]
    rows[[i]] <- list(
      cells = cells,
      section = if (is.na(sec)) NA_character_ else as.character(sec),
      kind = if (is.na(kind)) NA_character_ else as.character(kind)
    )
  }

  # Rebuild span_headers limited to active measures.
  span_headers <- list()
  if (length(x$span_map)) {
    for (lbl in names(x$span_map)) {
      cols <- intersect(x$span_map[[lbl]], measure_names)
      if (length(cols)) {
        span_headers[[length(span_headers) + 1L]] <- list(label = lbl, cols = cols)
      }
    }
  }

  ctx <- new_ks_context(
    id = x$id,
    type = x$meta$type %||% "Table",
    title = x$meta$title %||% character(),
    subtitles = x$meta$subtitles %||% character(),
    population = x$meta$population %||% NA_character_,
    columns = columns,
    span_headers = span_headers,
    rows = rows,
    n_rows_total = n,
    footnotes = x$meta$footnotes %||% character()
  )
  as_compact.ks_context(ctx)
}
