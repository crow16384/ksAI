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
