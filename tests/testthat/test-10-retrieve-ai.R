test_that("ks_annotate deterministic pass adds keywords/concepts", {
  store <- make_mock_capsule_store(member_ids = "14-3.01", labels = "Cardiac adverse events")
  out <- ks_annotate(store)
  expect_true(is_ks_capsule_store(out))
  kws <- vapply(out$capsules, function(c) length(c$keywords), integer(1))
  expect_true(any(kws > 0))
})

test_that("ks_embed stores numeric vectors (mocked endpoint)", {
  store <- make_mock_capsule_store()
  testthat::local_mocked_bindings(
    .embed_text = function(text, model, base_url) c(0.1, 0.2, 0.3)
  )
  out <- ks_embed(store, model = "m", base_url = "http://localhost:1234/v1")
  dims <- vapply(out$capsules, function(c) length(c$embedding %||% numeric()), integer(1))
  expect_true(all(dims == 3L))
})

test_that("ks_retrieve ranks capsules with embedding + keyword signals", {
  store <- make_mock_capsule_store(
    member_ids = "14-3.01",
    labels = "Cardiac disorders adverse events"
  )
  store <- ks_annotate(store)
  for (cid in names(store$capsules)) {
    l <- nchar(cid)
    store$capsules[[cid]]$embedding <- c(l, l / 2, 1)
  }
  testthat::local_mocked_bindings(
    .embed_text = function(text, model, base_url) c(20, 10, 1)
  )
  sub <- ks_retrieve(
    store,
    query = "cardiac disorders adverse events",
    n = 2L,
    filter = list(member_id = "14-3.01"),
    model = "m",
    base_url = "http://localhost:1234/v1"
  )
  expect_s3_class(sub, "ks_capsule_subset")
  expect_equal(length(sub$capsules), 2L)
  expect_true(all(c("capsule_id", "score") %in% names(sub$scores)))
})

test_that("ks_retrieve works without embeddings (keyword fallback)", {
  store <- make_mock_capsule_store(
    member_ids = "14-3.01",
    labels = "Weight baseline demographics"
  )
  store <- ks_annotate(store)
  for (cid in names(store$capsules)) {
    store$capsules[[cid]]$embedding <- NULL
  }
  testthat::local_mocked_bindings(
    .embed_text = function(text, model, base_url) stop("down")
  )
  sub <- ks_retrieve(store, query = "weight baseline", n = 2L)
  expect_s3_class(sub, "ks_capsule_subset")
  expect_equal(length(sub$capsules), 2L)
})

test_that("ks_reason builds ks_result from retrieved capsules (mocked chat)", {
  store <- make_mock_capsule_store(
    member_ids = "14-3.01",
    labels = "Cardiac findings"
  )
  store <- ks_annotate(store)
  for (cid in names(store$capsules)) {
    store$capsules[[cid]]$embedding <- c(1, 1, 1)
  }
  fake_chat <- list(chat = function(req) "reasoned answer")
  testthat::local_mocked_bindings(
    .embed_text = function(text, model, base_url) c(1, 1, 1),
    .make_ellmer_chat = function(...) fake_chat
  )
  out <- ks_reason(
    store,
    query = "Summarize cardiac findings",
    n = 2L,
    model = "m",
    provider = "ollama"
  )
  expect_true(is_ks_result(out))
  expect_equal(out$skill, "reason")
  expect_match(out$response, "reasoned answer", fixed = TRUE)
})
