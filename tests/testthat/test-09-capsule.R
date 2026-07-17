test_that("as_capsules builds capsule store from context", {
  dir <- make_fixture_demographics()
  ctx <- ks_load(dir, ids = "14-3.01")[["14-3.01"]]
  store <- as_capsules(ctx)

  expect_true(is_ks_capsule_store(store))
  expect_gt(length(store$capsules), 0L)
  ids <- names(store$capsules)
  expect_true(any(grepl("::SOC::", ids, fixed = TRUE)))
  expect_true(any(grepl("::PT::", ids, fixed = TRUE)))
  cap <- store$capsules[[ids[[1]]]]
  expect_true(is_ks_capsule(cap))
  expect_equal(cap$source_id, "14-3.01")
  expect_true(nzchar(cap$compact_text))
})

test_that("capsule stats extract n/pct/event-like fields", {
  dir <- make_fixture_demographics()
  ctx <- ks_load(dir, ids = "14-3.01")[["14-3.01"]]
  store <- as_capsules(ctx)
  any_stats <- vapply(store$capsules, function(c) length(c$stats) > 0, logical(1))
  expect_true(any(any_stats))
})

test_that("as_capsules on study links capsules to text outputs by inferred domain", {
  dir <- make_fixture_demographics()
  study <- ks_load(dir, ids = "14-3.01")
  # Add one synthetic text output in same study to exercise linking.
  study$texts[["txt-ae"]] <- ksAI:::new_ks_context(
    id = "txt-ae",
    type = "Text",
    title = c("Demographic Listing"),
    rows = list(),
    n_rows_total = 0L
  )

  store <- as_capsules(study)
  expect_true(is_ks_capsule_store(store))
  expect_true(length(store$capsules) > 0)
  has_link <- vapply(store$capsules, function(c) "txt-ae" %in% c$linked_ids, logical(1))
  expect_true(any(has_link))
})

test_that("save_capsules/load_capsules round-trip", {
  dir <- make_fixture_demographics()
  ctx <- ks_load(dir, ids = "14-3.01")[["14-3.01"]]
  store <- as_capsules(ctx)
  path <- tempfile(fileext = ".ksc")

  out <- save_capsules(store, path)
  expect_true(file.exists(out))
  loaded <- load_capsules(out)
  expect_true(is_ks_capsule_store(loaded))
  expect_equal(sort(names(loaded$capsules)), sort(names(store$capsules)))
})
