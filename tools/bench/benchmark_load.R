#!/usr/bin/env Rscript

## Phase 3 benchmark harness (exploratory; NOT part of the package).
##
## Answers the decision-gate question for a possible C++23 JSON reader:
## when ks_load() is slow, is the time spent in raw JSON *parsing* (which a
## C++ parser like simdjson/glaze would accelerate) or in R-side *row assembly*
## (which pure-R vectorisation would fix more cheaply)?
##
## Usage (from the package root):
##   Rscript tools/bench/benchmark_load.R [n_tables] [n_rows] [reps]
## Defaults: 40 tables, 500 rows/table, 5 reps.
##
## It generates a synthetic ksTFL-shaped meta folder, then times:
##   1. full ks_load()
##   2. raw jsonlite parse of every spec + data JSON
##   3. .build_rows() row assembly over pre-parsed data
## and prints a breakdown plus a pure-R vectorisation headroom probe.

suppressWarnings(suppressMessages({
  ok <- requireNamespace("jsonlite", quietly = TRUE)
}))
if (!ok) stop("jsonlite is required to run this benchmark.")

`%||%` <- function(x, y) if (is.null(x)) y else x

# ---------------------------------------------------------------------------
# Locate and load the package (dev sources) so internals are available.
# ---------------------------------------------------------------------------

.script_path <- function() {
  ca <- commandArgs(FALSE)
  m <- grep("^--file=", ca, value = TRUE)
  if (length(m)) normalizePath(sub("^--file=", "", m[[1]])) else NA_character_
}
sp <- .script_path()
root <- if (!is.na(sp)) normalizePath(file.path(dirname(sp), "..", "..")) else getwd()

loader <- if (requireNamespace("pkgload", quietly = TRUE)) {
  function() pkgload::load_all(root, quiet = TRUE)
} else if (requireNamespace("devtools", quietly = TRUE)) {
  function() devtools::load_all(root, quiet = TRUE)
} else {
  stop("Install 'pkgload' or 'devtools' to load the package for benchmarking.")
}
suppressMessages(loader())

# ---------------------------------------------------------------------------
# Arguments
# ---------------------------------------------------------------------------

args <- commandArgs(trailingOnly = TRUE)
n_tables <- as.integer(if (length(args) >= 1) args[[1]] else 40L)
n_rows   <- as.integer(if (length(args) >= 2) args[[2]] else 500L)
reps     <- as.integer(if (length(args) >= 3) args[[3]] else 5L)
max_rows <- n_rows  # measure full-table cost (no truncation) for a fair split

# ---------------------------------------------------------------------------
# Synthetic ksTFL-shaped meta folder generator
# ---------------------------------------------------------------------------

arm_labels <- c("Placebo<br>(N=86)", "Xanomeline Low Dose<br>(N=84)",
                "Xanomeline High Dose<br>(N=84)")

write_table <- function(dir, i, n_rows) {
  doc <- sprintf("14-3.%03d.docx", i)
  ref <- sprintf("data_ref_%03d", i)

  sections <- rep(c("Baseline", "Week 24", "End of Trt."), length.out = n_rows)
  kinds <- rep(c("detail", "detail", "label"), length.out = n_rows)

  data <- list(
    SECTION   = as.list(sections),
    ROW_LABEL = as.list(sprintf("Parameter %d", seq_len(n_rows))),
    ROW_KIND  = as.list(kinds),
    PLACEBO   = as.list(sprintf("%.1f (%.2f)", rnorm(n_rows), runif(n_rows, 1, 20))),
    LOWDOSE   = as.list(round(rnorm(n_rows) * 10, 1)),
    HIGHDOSE  = as.list(round(rnorm(n_rows) * 10, 1))
  )

  mk_col <- function(order, label, visible, type = "string", fmt = "%s") {
    list(colOrder = order, label = label, isVisible = visible,
         format = list(type = type, format = fmt, missings = "NA"))
  }
  cols <- list(
    SECTION   = mk_col(1, "SECTION", FALSE),
    ROW_LABEL = mk_col(2, "", TRUE),
    ROW_KIND  = mk_col(3, "ROW_KIND", FALSE),
    PLACEBO   = mk_col(4, arm_labels[1], TRUE),
    LOWDOSE   = mk_col(5, arm_labels[2], TRUE, "numeric", "%.1f"),
    HIGHDOSE  = mk_col(6, arm_labels[3], TRUE, "numeric", "%.1f")
  )

  spec_key <- paste0("table_spec_", ref)
  spec_entry <- list(
    document = list(docType = "Table", hasData = TRUE, docOrder = 1L),
    headers = list(
      list("Protocol: XYZ", "", "Page {PAGE}"),
      list("Population: Safety", "", "")
    ),
    footers = list(list(sprintf("Source: tfl-programs/t-%03d.R", i), "", "2026-07-05")),
    dataRef = list(ref),
    columns = cols,
    titles = list(title_0001 = list(
      text = list(sprintf("Table 14-3.%03d", i), "Synthetic Benchmark Table"),
      order = 1L, toclevel = 1L
    )),
    footnotes = list(footnote_0001 = list(text = list("Values are mean (SD)."), order = 1L))
  )
  spec <- list(`_metadata` = list(
    outDir = "/out", docFileName = doc, datetime = sprintf("2026-07-05T18:00:%02d", i %% 60),
    insertTOC = FALSE, tocTitle = "TOC"
  ))
  spec[[spec_key]] <- spec_entry

  spec_file <- paste0("spec_", ref, ".json")
  writeLines(jsonlite::toJSON(spec, auto_unbox = TRUE, null = "null"),
             file.path(dir, spec_file))
  writeLines(jsonlite::toJSON(data, auto_unbox = FALSE, null = "null"),
             file.path(dir, paste0(ref, ".json")))

  list(spec_file = spec_file, doc_file = doc,
       datetime = sprintf("2026-07-05T18:00:%02d", i %% 60),
       n_specs = 1L, data_refs = list(ref))
}

generate_meta <- function(n_tables, n_rows) {
  dir <- tempfile("ksai_bench_")
  dir.create(dir, recursive = TRUE)
  entries <- lapply(seq_len(n_tables), function(i) write_table(dir, i, n_rows))
  writeLines(jsonlite::toJSON(entries, auto_unbox = TRUE, pretty = TRUE),
             file.path(dir, "_index.json"))
  dir
}

# ---------------------------------------------------------------------------
# Timing helper (median + range of elapsed seconds)
# ---------------------------------------------------------------------------

bench <- function(fun, reps) {
  ts <- numeric(reps)
  for (i in seq_len(reps)) {
    gc(FALSE)
    t0 <- proc.time()[["elapsed"]]
    fun()
    ts[i] <- proc.time()[["elapsed"]] - t0
  }
  ts
}
ms <- function(x) sprintf("%8.1f ms", x * 1000)

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------

cat(sprintf(
  "\nksAI load benchmark\n  tables=%d  rows/table=%d  reps=%d  max_rows=%d\n\n",
  n_tables, n_rows, reps, max_rows
))

meta_dir <- generate_meta(n_tables, n_rows)
spec_files <- list.files(meta_dir, pattern = "^spec_.*\\.json$", full.names = TRUE)
data_files <- list.files(meta_dir, pattern = "^data_ref_.*\\.json$", full.names = TRUE)

# 1. Full ks_load()
t_total <- bench(function() ks_load(meta_dir, ids = NULL, max_rows = max_rows), reps)

# 2. Raw JSON parse only (spec + data files).
t_parse <- bench(function() {
  for (f in spec_files) jsonlite::fromJSON(f, simplifyVector = FALSE)
  for (d in data_files) jsonlite::fromJSON(d, simplifyVector = FALSE)
}, reps)

# 3. Row assembly only, over pre-parsed data.
tasks <- list()
for (f in spec_files) {
  s <- jsonlite::fromJSON(f, simplifyVector = FALSE)
  for (k in setdiff(names(s), "_metadata")) {
    entry <- s[[k]]
    dref <- as.character(entry$dataRef[[1]])
    data <- jsonlite::fromJSON(file.path(meta_dir, paste0(dref, ".json")),
                               simplifyVector = FALSE)
    tasks[[length(tasks) + 1L]] <- list(cols = entry$columns, data = data)
  }
}
t_assemble <- bench(function() {
  for (tk in tasks) ksAI:::.build_rows(tk$data, tk$cols, max_rows = max_rows)
}, reps)

med_total <- median(t_total)
med_parse <- median(t_parse)
med_asm   <- median(t_assemble)
med_other <- max(med_total - med_parse - med_asm, 0)

cat("Stage breakdown (median of ", reps, " reps):\n", sep = "")
cat("  full ks_load()      ", ms(med_total), "\n")
cat("  raw JSON parse      ", ms(med_parse),
    sprintf("  (%4.1f%% of total)\n", 100 * med_parse / med_total))
cat("  row assembly        ", ms(med_asm),
    sprintf("  (%4.1f%% of total)\n", 100 * med_asm / med_total))
cat("  index / IO / other  ", ms(med_other),
    sprintf("  (%4.1f%% of total)\n", 100 * med_other / med_total))

# ---------------------------------------------------------------------------
# Pure-R vectorisation headroom probe (numeric column formatting)
# ---------------------------------------------------------------------------

raw_num <- as.list(round(rnorm(n_rows * n_tables) * 10, 3))
fmt_current <- function() ksAI:::.format_column(raw_num, "numeric", "%.1f", "NA")
fmt_vector  <- function() {
  v <- as.numeric(unlist(raw_num, use.names = FALSE))
  out <- sprintf("%.1f", v)
  out[is.na(v)] <- "NA"
  out
}
h_cur <- median(bench(fmt_current, reps))
h_vec <- median(bench(fmt_vector, reps))

cat("\nPure-R formatter headroom (", length(raw_num), " numeric cells):\n", sep = "")
cat("  current .format_column ", ms(h_cur), "\n")
cat("  vectorised reference   ", ms(h_vec),
    sprintf("  (%.1fx faster)\n", h_cur / max(h_vec, 1e-9)))

# ---------------------------------------------------------------------------
# Decision-gate hint
# ---------------------------------------------------------------------------

parse_share <- med_parse / med_total
cat("\nDecision hint:\n")
if (parse_share >= 0.5) {
  cat("  Parsing dominates (", sprintf("%.0f%%", 100 * parse_share),
      ") -> a C++23 JSON parser (simdjson/glaze) is worth prototyping.\n", sep = "")
} else {
  cat("  Assembly/other dominates (parse only ",
      sprintf("%.0f%%", 100 * parse_share),
      ") -> try pure-R vectorisation before committing to C++.\n", sep = "")
}
cat("  Full load median: ", ms(med_total), " for ", n_tables, " tables x ",
    n_rows, " rows.\n\n", sep = "")

unlink(meta_dir, recursive = TRUE)
