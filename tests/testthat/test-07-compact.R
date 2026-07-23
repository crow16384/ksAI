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

test_that("as_compact handles span cols missing from visible columns", {
  ctx <- ksAI:::new_ks_context(
    id = "T-span",
    type = "Table",
    title = "Span mismatch",
    population = "Safety",
    columns = list(
      list(name = "ROW_LABEL", label = "", is_grouping = FALSE),
      list(name = "N_A", label = "n", is_grouping = FALSE),
      list(name = "PCT_A", label = "%", is_grouping = FALSE)
    ),
    span_headers = list(
      list(label = "Arm A", cols = c("N_A", "PCT_A", "INVISIBLE_COL"))
    ),
    rows = list(
      list(
        cells = list(ROW_LABEL = "Age", N_A = "10", PCT_A = "50.0"),
        section = NA_character_,
        kind = NA_character_
      )
    ),
    n_rows_total = 1L
  )

  txt <- as_compact(ctx)
  expect_match(txt, "SPANS:", fixed = TRUE)
  expect_match(txt, "Arm A", fixed = TRUE)
  expect_match(txt, "Age:", fixed = TRUE)
  # Must not throw on INVISIBLE_COL; may omit it when visible cols exist.
  expect_false(grepl("subscript out of bounds", txt, fixed = TRUE))
})

test_that("as_capsules survives span/column mismatches via compact path", {
  ctx <- ksAI:::new_ks_context(
    id = "14-9.99",
    type = "Table",
    title = "Adverse events with bad span ref",
    population = "Safety",
    columns = list(
      list(name = "AEDECOD", label = "Preferred Term", is_grouping = FALSE),
      list(name = "N_P", label = "n", is_grouping = FALSE)
    ),
    span_headers = list(
      list(label = "Placebo", cols = c("N_P", "MISSING_MEASURE"))
    ),
    rows = list(
      list(
        cells = list(AEDECOD = "CARDIAC DISORDERS", N_P = "3 (3.5%)"),
        section = "CARDIAC DISORDERS",
        kind = "SOC"
      ),
      list(
        cells = list(AEDECOD = "SINUS BRADYCARDIA", N_P = "2 (2.3%)"),
        section = "CARDIAC DISORDERS",
        kind = "PT"
      )
    ),
    n_rows_total = 2L
  )

  store <- as_capsules(ctx)
  expect_true(is_ks_capsule_store(store))
  expect_gt(length(store$capsules), 0L)
  expect_true(any(nzchar(vapply(store$capsules, function(c) c$compact_text, ""))))
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
