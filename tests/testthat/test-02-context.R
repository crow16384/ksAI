test_that("new_ks_context builds a valid object", {
  ctx <- ksAI:::new_ks_context(id = "T1", type = "Table", title = "My Table")
  expect_true(is_ks_context(ctx))
  expect_equal(ctx$id, "T1")
  expect_equal(ctx$n_rows_total, 0L)
})

test_that("as_json produces parseable JSON", {
  ctx <- ksAI:::new_ks_context(id = "T1", type = "Table", title = "My Table")
  js <- as_json(ctx)
  expect_type(js, "character")
  parsed <- jsonlite::fromJSON(js, simplifyVector = FALSE)
  expect_equal(parsed$id, "T1")
})

test_that("enrich_context overlays without mutating the original", {
  ctx <- ksAI:::new_ks_context(id = "T1", type = "Table",
                               annotations = list(a = 1))
  ctx2 <- enrich_context(ctx, population = "ITT",
                         annotations = list(b = 2))
  expect_true(is.na(ctx$population))          # original untouched
  expect_equal(ctx2$population, "ITT")
  expect_equal(ctx2$annotations, list(a = 1, b = 2))  # merged, not replaced
})

test_that("enrich_context validates inputs", {
  ctx <- ksAI:::new_ks_context(id = "T1", type = "Table")
  expect_error(enrich_context(list()), "ks_context")
  expect_error(enrich_context(ctx, annotations = list(1)), "named")
})

test_that("as_markdown renders human labels, sections and footnotes", {
  dir <- make_fixture_study(n_tables = 1L, n_rows = 3L)
  study <- load_study(dir)
  md <- as_markdown(study[["14-3.01"]])

  expect_type(md, "character")
  # Human column label is used, not the raw arm code.
  expect_true(grepl("Placebo (N=79)", md, fixed = TRUE))
  expect_false(grepl("PLACEBO", md, fixed = TRUE))
  # Section subheader and a Markdown table are present.
  expect_true(grepl("**Baseline**", md, fixed = TRUE))
  expect_true(grepl("| --- |", md, fixed = TRUE))
  # Footnotes are appended.
  expect_true(grepl("Footnotes", md, fixed = TRUE))
})

test_that("as_markdown notes truncation and pipes are escaped", {
  ctx <- ksAI:::new_ks_context(
    id = "T9", type = "Table", title = "Trunc",
    columns = list(A = list(name = "A", label = "Arm|A", type = "string",
                            format_string = "%s")),
    rows = list(list(cells = list(A = "x|y"), section = "S1", kind = "detail")),
    n_rows_total = 5L
  )
  md <- as_markdown(ctx)
  expect_true(grepl("Showing 1 of 5 rows", md, fixed = TRUE))
  # Pipe characters inside labels/cells are escaped so the table stays valid.
  expect_true(grepl("Arm\\|A", md, fixed = TRUE))
  expect_true(grepl("x\\|y", md, fixed = TRUE))
})

test_that("as_markdown handles non-table outputs without rows", {
  fig <- ksAI:::new_ks_context(id = "F1", type = "Figure", title = "A Figure")
  md <- as_markdown(fig)
  expect_true(grepl("Figure output", md, fixed = TRUE))
})
