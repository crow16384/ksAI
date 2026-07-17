test_that(".parse_population extracts the population from headers", {
  headers <- list(
    list("Protocol: X", "", "Page 1"),
    list("Population: Safety", "", "")
  )
  expect_equal(ksAI:::.parse_population(headers), "Safety")
})

test_that(".parse_source extracts the source from footers", {
  footers <- list(list("Source: tfl-programs/t.R", "", "2026-07-05"))
  expect_equal(ksAI:::.parse_source(footers), "tfl-programs/t.R")
})

test_that(".parse_labelled returns NA when absent", {
  expect_true(is.na(ksAI:::.parse_population(list(list("x", "y", "z")))))
  expect_true(is.na(ksAI:::.parse_population(NULL)))
})

test_that(".clean_label strips HTML markup", {
  expect_equal(ksAI:::.clean_label("Placebo<br>(N=79)"), "Placebo (N=79)")
  expect_equal(ksAI:::.clean_label("p-value <sup>[1]</sup>"), "p-value [1]")
  expect_equal(ksAI:::.clean_label(NULL), "")
})

test_that(".extract_text_entries orders by $order and collapses text", {
  entries <- list(
    b = list(text = list("second"), order = 2L),
    a = list(text = list("first", "line"), order = 1L)
  )
  expect_equal(ksAI:::.extract_text_entries(entries), c("first", "line", "second"))
  expect_equal(ksAI:::.extract_text_entries(NULL), character())
})

test_that(".build_rows keeps visible cols in cells and control cols as metadata", {
  columns <- list(
    SECTION = list(isVisible = FALSE, format = list(type = "string", format = "%s")),
    ROW_LABEL = list(isVisible = TRUE, format = list(type = "string", format = "%s")),
    ROW_KIND = list(isVisible = FALSE, format = list(type = "string", format = "%s")),
    PLACEBO = list(isVisible = TRUE, format = list(type = "string", format = "%s"))
  )
  data <- list(
    SECTION = list("Baseline", "Week 24"),
    ROW_LABEL = list("n", "Mean"),
    ROW_KIND = list("detail", "label"),
    PLACEBO = list("79", "24.1")
  )
  built <- ksAI:::.build_rows(data, columns)
  expect_equal(built$n_rows_total, 2L)
  expect_equal(length(built$rows), 2L)
  # visible-only cells
  expect_equal(names(built$rows[[1]]$cells), c("ROW_LABEL", "PLACEBO"))
  expect_equal(built$rows[[1]]$cells$PLACEBO, "79")
  # control columns lifted to row metadata
  expect_equal(built$rows[[1]]$section, "Baseline")
  expect_equal(built$rows[[2]]$kind, "label")
})

test_that(".build_rows formats numeric columns and applies missings", {
  columns <- list(
    X = list(isVisible = TRUE, format = list(type = "numeric", format = "%.1f", missings = "NA"))
  )
  data <- list(X = list(24.15, NA, 3))
  built <- ksAI:::.build_rows(data, columns)
  expect_equal(built$rows[[1]]$cells$X, "24.1")
  expect_equal(built$rows[[2]]$cells$X, "NA")
  expect_equal(built$rows[[3]]$cells$X, "3.0")
})

test_that(".build_rows truncates and warns", {
  columns <- list(X = list(isVisible = TRUE, format = list(type = "string", format = "%s")))
  data <- list(X = as.list(as.character(seq_len(250))))
  built <- ksAI:::.build_rows(data, columns, max_rows = 200L)
  expect_equal(built$n_rows_total, 250L)
  expect_equal(length(built$rows), 200L)
  expect_length(built$warnings, 1L)
})

test_that("ks_list_ids discovers available outputs without loading data", {
  dir <- make_fixture_study(n_tables = 2L, n_rows = 3L)
  ids <- ks_list_ids(dir)

  expect_true(all(c("id", "type", "title") %in% names(ids)))
  expect_equal(nrow(ids), 2L)
  expect_setequal(ids$id, c("14-3.01", "14-3.02"))
})

test_that("ks_load imports only requested IDs", {
  dir <- make_fixture_study(n_tables = 3L, n_rows = 3L)
  study <- ks_load(dir, ids = c("14-3.03", "14-3.01"))

  expect_true(is_ks_study(study))
  expect_equal(names(study$tables), c("14-3.03", "14-3.01"))
  t1 <- study[["14-3.01"]]
  expect_true(is_ks_context(t1))
  expect_equal(t1$population, "Efficacy")
  expect_equal(t1$columns$PLACEBO$label, "Placebo (N=79)")
})

test_that("ks_load errors on unknown requested IDs", {
  dir <- make_fixture_study(n_tables = 1L, n_rows = 2L)
  expect_error(ks_load(dir, ids = c("14-3.01", "no-such-id")), "Missing id")
})

test_that("ks_load(ids = NULL) loads all outputs", {
  dir <- make_fixture_study(n_tables = 2L, n_rows = 2L)
  study <- ks_load(dir, ids = NULL)
  expect_equal(length(study$tables), 2L)
})

test_that("ks_load preserves is_grouping and subtitles", {
  dir <- make_fixture_demographics()
  study <- ks_load(dir, ids = "14-3.01")
  ctx <- study[["14-3.01"]]

  expect_equal(ctx$subtitles, "Randomized Subjects")
  expect_true(isTRUE(ctx$columns$VISIT$is_grouping))
  expect_false(isTRUE(ctx$columns$ROW_LABEL$is_grouping))
  expect_false(isTRUE(ctx$columns$MEAN_A$is_grouping))
  expect_equal(length(ctx$span_headers), 2L)
  expect_equal(ctx$span_headers[[1]]$label, "Drug A (N=121)")
})

test_that(".extract_columns keeps is_grouping flag", {
  columns <- list(
    ROW_LABEL = list(colOrder = 1, label = "", isVisible = TRUE,
                     format = list(type = "string", format = "%s")),
    VISIT = list(colOrder = 2, label = "Visit", isVisible = TRUE, isGrouping = TRUE,
                 format = list(type = "string", format = "%s")),
    MEAN = list(colOrder = 3, label = "Mean", isVisible = TRUE, isGrouping = FALSE,
                format = list(type = "string", format = "%s"))
  )
  out <- ksAI:::.extract_columns(columns)
  expect_false(out$ROW_LABEL$is_grouping)
  expect_true(out$VISIT$is_grouping)
  expect_false(out$MEAN$is_grouping)
})
