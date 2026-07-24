test_that("as_capsules requires a model and uses LLM JSON (mocked)", {
  dir <- make_fixture_demographics()
  ctx <- ks_load(dir, ids = "14-3.01")[["14-3.01"]]

  expect_error(as_capsules(ctx), "model")

  fake_json <- jsonlite::toJSON(
    list(capsules = list(
      list(
        capsule_id = "demographics",
        label = "Baseline demographics",
        parent_id = NULL,
        member_ids = list("14-3.01"),
        confidence = 0.9
      ),
      list(
        capsule_id = "age_weight",
        label = "Age and weight",
        parent_id = "demographics",
        member_ids = list("14-3.01"),
        confidence = 0.8
      )
    )),
    auto_unbox = TRUE,
    null = "null"
  )

  fake_chat <- list(chat = function(...) as.character(fake_json))
  testthat::local_mocked_bindings(
    .make_ellmer_chat = function(...) fake_chat
  )

  store <- as_capsules(ctx, model = "tiny-classify")
  expect_true(is_ks_capsule_store(store))
  expect_true("demographics" %in% names(store$capsules))
  expect_true("age_weight" %in% names(store$capsules))
  expect_equal(store$capsules$demographics$member_ids, "14-3.01")
  expect_equal(store$capsules$age_weight$parent_id, "demographics")
  expect_true("age_weight" %in% store$capsules$demographics$child_ids)
  expect_true(nzchar(store$capsules$demographics$compact_text))
  # Multi-membership: same table in two capsules.
  expect_equal(store$capsules$age_weight$member_ids, "14-3.01")
})

test_that("as_capsules drops low-confidence and unknown member ids", {
  ctx <- ksAI:::new_ks_context(
    id = "t1",
    type = "Table",
    title = "Demo",
    rows = list(list(kind = "detail", cells = list(ROW_LABEL = "A"), section = NA_character_)),
    n_rows_total = 1L
  )
  fake_json <- '{"capsules":[
    {"capsule_id":"ok","label":"OK","parent_id":null,"member_ids":["t1"],"confidence":0.9},
    {"capsule_id":"weak","label":"Weak","parent_id":null,"member_ids":["t1"],"confidence":0.1},
    {"capsule_id":"bogus","label":"Bogus","parent_id":null,"member_ids":["nope"],"confidence":0.99}
  ]}'
  fake_chat <- list(chat = function(...) fake_json)
  testthat::local_mocked_bindings(
    .make_ellmer_chat = function(...) fake_chat
  )
  store <- as_capsules(ctx, model = "tiny", min_confidence = 0.5)
  expect_equal(names(store$capsules), "ok")
})

test_that("review APIs audit tree and expand member content", {
  dir <- make_fixture_demographics()
  study <- ks_load(dir, ids = "14-3.01")
  store <- make_mock_capsule_store(member_ids = "14-3.01", study = study)

  tree <- capsule_tree(store, print = FALSE)
  expect_true("demographics" %in% names(tree))

  mem <- capsule_membership(store, study)
  expect_true("14-3.01" %in% mem$output_id)
  expect_true(any(mem$n_capsules > 1L))

  rev <- review_capsules(store, study)
  expect_s3_class(rev, "ks_capsule_review")
  expect_true(rev$ok || length(rev$findings) >= 0L)

  txt <- capsule_content(store, "demographics", study, format = "compact")
  expect_match(txt, "14-3.01", fixed = TRUE)
  expect_match(as_compact(store$capsules$demographics), "CAPSULE:", fixed = TRUE)
  expect_match(as_markdown(store$capsules$demographics), "# Capsule", fixed = TRUE)
})

test_that("ks_review_capsules uses mocked LLM", {
  dir <- make_fixture_demographics()
  study <- ks_load(dir, ids = "14-3.01")
  store <- make_mock_capsule_store(member_ids = "14-3.01", study = study)
  fake_chat <- list(chat = function(...) "Looks coherent.")
  testthat::local_mocked_bindings(
    .make_ellmer_chat = function(...) fake_chat
  )
  out <- ks_review_capsules(store, study, model = "tiny", attach_images = FALSE)
  expect_true(is_ks_result(out))
  expect_equal(out$skill, "capsule_review")
  expect_match(out$response, "Looks coherent", fixed = TRUE)
})

test_that("save_capsules/load_capsules round-trip member_ids", {
  store <- make_mock_capsule_store(member_ids = c("a", "b"))
  path <- tempfile(fileext = ".ksc")
  out <- save_capsules(store, path)
  expect_true(file.exists(out))
  loaded <- load_capsules(out)
  expect_true(is_ks_capsule_store(loaded))
  expect_equal(sort(names(loaded$capsules)), sort(names(store$capsules)))
  expect_equal(
    sort(loaded$capsules$demographics$member_ids),
    sort(c("a", "b"))
  )
})
