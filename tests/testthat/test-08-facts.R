test_that("as_facts builds a ks_facts object from demographics context", {
  dir <- make_fixture_demographics()
  ctx <- ks_load(dir, ids = "14-3.01")[["14-3.01"]]
  facts <- as_facts(ctx)

  expect_true(is_ks_facts(facts))
  expect_equal(facts$id, "14-3.01")
  expect_equal(facts$schema$row_label, "ROW_LABEL")
  expect_equal(facts$schema$dim_names, "VISIT")
  expect_true("MEAN_A" %in% facts$schema$measure_names)
  expect_equal(length(facts$span_map), 2L)

  dicts <- ksAI:::ks_get_dictionaries(facts$ptr)
  expect_equal(dicts$n_rows, 3L)
  expect_true("Age (years)" %in% dicts$row_label)
})

test_that("retrieve by rows keeps matching row labels only", {
  dir <- make_fixture_demographics()
  facts <- as_facts(ks_load(dir, ids = "14-3.01")[["14-3.01"]])
  sub <- retrieve(facts, rows = "Age (years)")
  decoded <- ksAI:::ks_decode_facts(sub$ptr)

  expect_equal(decoded$n_rows, 1L)
  expect_equal(as.character(decoded$row_label), "Age (years)")
  expect_false("Weight (kg)" %in% as.character(decoded$row_label))
})

test_that("retrieve by sections filters correctly", {
  dir <- make_fixture_demographics()
  facts <- as_facts(ks_load(dir, ids = "14-3.01")[["14-3.01"]])
  sub <- retrieve(facts, sections = "Baseline Characteristics")
  decoded <- ksAI:::ks_decode_facts(sub$ptr)
  expect_equal(decoded$n_rows, 3L)

  empty <- retrieve(facts, sections = "Nonexistent")
  expect_equal(ksAI:::ks_decode_facts(empty$ptr)$n_rows, 0L)
})

test_that("retrieve by spans drops other arm measure columns", {
  dir <- make_fixture_demographics()
  facts <- as_facts(ks_load(dir, ids = "14-3.01")[["14-3.01"]])
  sub <- retrieve(facts, spans = "Drug A (N=121)")
  txt <- as_compact(sub)

  expect_match(txt, "Drug A", fixed = TRUE)
  expect_false(grepl("B=Placebo", txt, fixed = TRUE))
  expect_false(grepl("Placebo \\(N=118\\)", txt))
  expect_true("N_A" %in% sub$measure_filter)
  expect_false("N_P" %in% sub$measure_filter)
})

test_that("as_facts -> retrieve -> as_compact round-trip preserves values", {
  dir <- make_fixture_demographics()
  ctx <- ks_load(dir, ids = "14-3.01")[["14-3.01"]]
  txt <- as_facts(ctx) |> retrieve() |> as_compact()

  expect_match(txt, "TABLE: 14-3.01", fixed = TRUE)
  expect_match(txt, "Age (years)", fixed = TRUE)
  expect_match(txt, "63.2", fixed = TRUE)
  expect_match(txt, "61.7", fixed = TRUE)
  expect_match(txt, "Weight (kg)", fixed = TRUE)
})

test_that("as_compact.ks_facts matches as_compact.ks_context shape", {
  dir <- make_fixture_demographics()
  ctx <- ks_load(dir, ids = "14-3.01")[["14-3.01"]]
  from_ctx <- as_compact(ctx)
  from_facts <- as_compact(as_facts(ctx))

  expect_match(from_facts, "Population: ITT", fixed = TRUE)
  expect_match(from_facts, "[Baseline Characteristics]", fixed = TRUE)
  expect_match(from_facts, "SPANS:", fixed = TRUE)
  expect_match(from_facts, "Drug A (N=121)", fixed = TRUE)
  # Same core values present in both.
  expect_true(grepl("63.2", from_ctx, fixed = TRUE))
  expect_true(grepl("63.2", from_facts, fixed = TRUE))
})

test_that(".classify_columns separates dims from measures", {
  columns <- list(
    list(name = "ROW_LABEL", label = "", is_grouping = FALSE),
    list(name = "VISIT", label = "Visit", is_grouping = TRUE),
    list(name = "MEAN", label = "Mean", is_grouping = FALSE)
  )
  schema <- ksAI:::.classify_columns(columns)
  expect_equal(schema$row_label, "ROW_LABEL")
  expect_equal(schema$dim_names, "VISIT")
  expect_equal(schema$measure_names, "MEAN")
})
