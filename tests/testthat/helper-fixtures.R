# Fixture builders that emit JSON in the exact shape produced by
# ksTFL::save_report(), so tests exercise the real import path.

# Write a spec JSON + its data JSON into `dir`, and return the spec filename.
# `columns` is a named list of column defs; `data` is a named columnar list.
write_fixture_table <- function(dir,
                                doc_file = "14-3.01.docx",
                                data_ref = "data_ref_1",
                                spec_file = NULL,
                                title = c("Table 14-3.01", "Summary"),
                                population = "Efficacy",
                                source = "tfl-programs/t.R",
                                columns = NULL,
                                data = NULL,
                                stub_columns = NULL,
                                footnotes = c("Values are n (%)."),
                                datetime = "2026-07-05T18:00:00") {
  if (is.null(columns)) {
    columns <- list(
      SECTION = list(colOrder = 1, label = "SECTION", isVisible = FALSE,
                     format = list(type = "string", format = "%s", missings = "")),
      ROW_LABEL = list(colOrder = 2, label = "", isVisible = TRUE,
                       format = list(type = "string", format = "%s", missings = "")),
      ROW_KIND = list(colOrder = 3, label = "ROW_KIND", isVisible = FALSE,
                      format = list(type = "string", format = "%s", missings = "")),
      PLACEBO = list(colOrder = 4, label = "Placebo<br>(N=79)", isVisible = TRUE,
                     format = list(type = "string", format = "%s", missings = "")),
      COUNT = list(colOrder = 5, label = "N", isVisible = TRUE,
                   format = list(type = "numeric", format = "%.1f", missings = "NA"))
    )
  }
  if (is.null(data)) {
    data <- list(
      SECTION = list("Baseline", "Baseline", "Week 24"),
      ROW_LABEL = list("n", "Mean (SD)", "n"),
      ROW_KIND = list("detail", "detail", "detail"),
      PLACEBO = list("79", "24.1 (12.19)", "79"),
      COUNT = list(79, 24.1, NA)
    )
  }

  spec_key <- paste0("table_spec_", data_ref)
  spec_entry <- list(
    document = list(docType = "Table", hasData = TRUE, docOrder = 1L),
    headers = list(
      list("Protocol: X", "", "Page {PAGE}"),
      list(paste0("Population: ", population), "", "")
    ),
    footers = list(
      list(paste0("Source: ", source), "", "2026-07-05")
    ),
    dataRef = list(data_ref),
    columns = columns,
    titles = list(
      title_0001 = list(text = as.list(title), order = 1L, toclevel = 1L)
    ),
    footnotes = list(
      footnote_0001 = list(text = as.list(footnotes), order = 1L)
    )
  )
  if (!is.null(stub_columns)) {
    spec_entry$stubColumns <- stub_columns
  }

  spec <- list(
    `_metadata` = list(
      outDir = "/out", docFileName = doc_file, datetime = datetime,
      insertTOC = FALSE, tocTitle = "TOC"
    )
  )
  spec[[spec_key]] <- spec_entry

  if (is.null(spec_file)) {
    spec_file <- paste0("spec_", data_ref, ".json")
  }
  writeLines(
    jsonlite::toJSON(spec, auto_unbox = TRUE, null = "null"),
    file.path(dir, spec_file)
  )
  writeLines(
    jsonlite::toJSON(data, auto_unbox = FALSE, null = "null"),
    file.path(dir, paste0(data_ref, ".json"))
  )
  spec_file
}

# Write an _index.json describing the given spec files.
write_fixture_index <- function(dir, entries) {
  writeLines(
    jsonlite::toJSON(entries, auto_unbox = TRUE, pretty = TRUE),
    file.path(dir, "_index.json")
  )
}

# Build a complete single-table fixture meta folder; return the folder path.
make_fixture_study <- function(n_tables = 1L, n_rows = 3L) {
  dir <- file.path(tempfile("ksai_fixture_"))
  dir.create(dir, recursive = TRUE)
  entries <- list()
  for (i in seq_len(n_tables)) {
    doc <- sprintf("14-3.%02d.docx", i)
    ref <- sprintf("data_ref_%02d", i)
    data <- list(
      SECTION = as.list(rep("Baseline", n_rows)),
      ROW_LABEL = as.list(paste0("row", seq_len(n_rows))),
      ROW_KIND = as.list(rep("detail", n_rows)),
      PLACEBO = as.list(as.character(seq_len(n_rows)))
    )
    cols <- list(
      SECTION = list(colOrder = 1, label = "SECTION", isVisible = FALSE,
                     format = list(type = "string", format = "%s", missings = "")),
      ROW_LABEL = list(colOrder = 2, label = "", isVisible = TRUE,
                       format = list(type = "string", format = "%s", missings = "")),
      ROW_KIND = list(colOrder = 3, label = "ROW_KIND", isVisible = FALSE,
                      format = list(type = "string", format = "%s", missings = "")),
      PLACEBO = list(colOrder = 4, label = "Placebo<br>(N=79)", isVisible = TRUE,
                     format = list(type = "string", format = "%s", missings = ""))
    )
    sf <- write_fixture_table(
      dir, doc_file = doc, data_ref = ref,
      title = c(sprintf("Table 14-3.%02d", i), "Fixture"),
      columns = cols, data = data
    )
    entries[[i]] <- list(
      spec_file = sf, doc_file = doc,
      datetime = sprintf("2026-07-05T18:00:%02d", i),
      n_specs = 1L, data_refs = list(ref)
    )
  }
  write_fixture_index(dir, entries)
  dir
}
