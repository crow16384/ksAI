# Fixture builders that emit JSON in the exact shape produced by
# ksTFL::save_report(), so tests exercise the real import path.

# Write a spec JSON + its data JSON into `dir`, and return the spec filename.
# `columns` is a named list of column defs; `data` is a named columnar list.
write_fixture_table <- function(dir,
                                doc_file = "14-3.01.docx",
                                data_ref = "data_ref_1",
                                spec_file = NULL,
                                title = c("Table 14-3.01", "Summary"),
                                subtitles = NULL,
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
  if (!is.null(subtitles)) {
    spec_entry$subtitles <- list(
      subtitle_0001 = list(text = as.list(subtitles), order = 1L)
    )
  }
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

# Demographics-style fixture with span headers (two treatment arms).
make_fixture_demographics <- function() {
  dir <- file.path(tempfile("ksai_demo_"))
  dir.create(dir, recursive = TRUE)

  columns <- list(
    SECTION = list(colOrder = 1, label = "SECTION", isVisible = FALSE,
                   format = list(type = "string", format = "%s", missings = "")),
    ROW_LABEL = list(colOrder = 2, label = "", isVisible = TRUE,
                     format = list(type = "string", format = "%s", missings = "")),
    ROW_KIND = list(colOrder = 3, label = "ROW_KIND", isVisible = FALSE,
                    format = list(type = "string", format = "%s", missings = "")),
    VISIT = list(colOrder = 4, label = "Visit", isVisible = TRUE, isGrouping = TRUE,
                 format = list(type = "string", format = "%s", missings = "")),
    N_A = list(colOrder = 5, label = "N", isVisible = TRUE,
               format = list(type = "string", format = "%s", missings = "")),
    MEAN_A = list(colOrder = 6, label = "Mean", isVisible = TRUE,
                  format = list(type = "string", format = "%s", missings = "")),
    SD_A = list(colOrder = 7, label = "SD", isVisible = TRUE,
                format = list(type = "string", format = "%s", missings = "")),
    N_P = list(colOrder = 8, label = "N", isVisible = TRUE,
               format = list(type = "string", format = "%s", missings = "")),
    MEAN_P = list(colOrder = 9, label = "Mean", isVisible = TRUE,
                  format = list(type = "string", format = "%s", missings = "")),
    SD_P = list(colOrder = 10, label = "SD", isVisible = TRUE,
                format = list(type = "string", format = "%s", missings = ""))
  )
  data <- list(
    SECTION = list("Baseline Characteristics", "Baseline Characteristics", "Baseline Characteristics"),
    ROW_LABEL = list("Age (years)", "Weight (kg)", "BMI"),
    ROW_KIND = list("detail", "detail", "detail"),
    VISIT = list("Baseline", "Baseline", "Baseline"),
    N_A = list("121", "121", "121"),
    MEAN_A = list("63.2", "72.1", "26.4"),
    SD_A = list("11.5", "14.2", "4.1"),
    N_P = list("118", "118", "118"),
    MEAN_P = list("61.7", "70.9", "25.9"),
    SD_P = list("10.8", "13.8", "3.9")
  )
  stubs <- list(
    stub_a = list(label = "Drug A (N=121)", stubOrder = 0L,
                  cols = list("N_A", "MEAN_A", "SD_A")),
    stub_p = list(label = "Placebo (N=118)", stubOrder = 1L,
                  cols = list("N_P", "MEAN_P", "SD_P"))
  )
  sf <- write_fixture_table(
    dir,
    doc_file = "14-3.01.docx",
    data_ref = "data_demo",
    title = c("Table 14.2.1", "Demographic Characteristics"),
    subtitles = c("Randomized Subjects"),
    population = "ITT",
    columns = columns,
    data = data,
    stub_columns = stubs,
    footnotes = c("Values are mean (SD) unless otherwise noted.")
  )
  write_fixture_index(dir, list(list(
    spec_file = sf, doc_file = "14-3.01.docx",
    datetime = "2026-07-05T18:00:01",
    n_specs = 1L, data_refs = list("data_demo")
  )))
  dir
}
