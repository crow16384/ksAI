test_that("as_compact is shorter than as_markdown", {
  dir <- make_fixture_demographics()
  ctx <- ks_load(dir, ids = "14-3.01")[["14-3.01"]]
  compact <- as_compact(ctx)
  md <- as_markdown(ctx)
  expect_lt(nchar(compact), nchar(md))
  # Larger tables see ≥30% savings; small fixtures still must beat markdown.
  expect_lte(nchar(compact) / nchar(md), 0.95)
})

test_that("as_compact renders span-grouped demographics DSL", {
  dir <- make_fixture_demographics()
  ctx <- ks_load(dir, ids = "14-3.01")[["14-3.01"]]
  txt <- as_compact(ctx)

  expect_match(txt, "TABLE: 14-3\\.01 \\| Population: ITT", perl = TRUE)
  expect_match(txt, "TITLE: Table 14\\.2\\.1", perl = TRUE)
  expect_match(txt, "SUBTITLE: Randomized Subjects", fixed = TRUE)
  expect_match(txt, "SPANS:", fixed = TRUE)
  expect_match(txt, "A=Drug A (N=121)", fixed = TRUE)
  expect_match(txt, "B=Placebo (N=118)", fixed = TRUE)
  expect_match(txt, "COLS:", fixed = TRUE)
  expect_match(txt, "[Baseline Characteristics]", fixed = TRUE)
  expect_match(txt, "Age \\(years\\):", perl = TRUE)
  expect_match(txt, "A: ", fixed = TRUE)
  expect_match(txt, "Footnotes:", fixed = TRUE)
  expect_match(txt, "Values are mean \\(SD\\)", perl = TRUE)
})

test_that("as_compact renders flat tables without span headers", {
  dir <- make_fixture_study(n_tables = 1L, n_rows = 3L)
  ctx <- ks_load(dir, ids = "14-3.01")[["14-3.01"]]
  txt <- as_compact(ctx)

  expect_match(txt, "TABLE: 14-3\\.01", perl = TRUE)
  expect_match(txt, "COLS:", fixed = TRUE)
  expect_match(txt, "[Baseline]", fixed = TRUE)
  expect_match(txt, "row1:", fixed = TRUE)
})

test_that("as_compact handles non-table outputs without rows", {
  fig <- ksAI:::new_ks_context(id = "F1", type = "Figure", title = "A Figure")
  txt <- as_compact(fig)
  expect_match(txt, "TABLE: F1", fixed = TRUE)
  expect_match(txt, "Figure output", fixed = TRUE)
})

test_that("as_compact includes footnotes for empty tables", {
  ctx <- ksAI:::new_ks_context(
    id = "T1", type = "Table", title = "Empty",
    footnotes = c("Note A")
  )
  txt <- as_compact(ctx)
  expect_match(txt, "No data rows", fixed = TRUE)
  expect_match(txt, "- Note A", fixed = TRUE)
})
