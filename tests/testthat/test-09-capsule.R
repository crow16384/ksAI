test_that("domain inference is multilingual, structural, and overridable", {
  infer <- ksAI:::.capsule_infer_domain

  # Multilingual lexicon (RU / ZH titles; no English keywords).
  ctx_ru <- ksAI:::new_ks_context(
    id = "tbl-ндя-01",
    type = "Table",
    title = c("Таблица", "Нежелательные явления по системе органов"),
    rows = list(),
    n_rows_total = 0L
  )
  expect_equal(infer(ctx_ru), "AE")

  ctx_zh <- ksAI:::new_ks_context(
    id = "t-lab",
    type = "Table",
    title = "实验室检查汇总",
    rows = list(),
    n_rows_total = 0L
  )
  expect_equal(infer(ctx_zh), "LB")

  # MedDRA structure wins without title keywords.
  ctx_soc <- ksAI:::new_ks_context(
    id = "opaque-01",
    type = "Table",
    title = "Таблица результатов",
    rows = list(
      list(kind = "SOC", label = "CARDIAC DISORDERS", values = list()),
      list(kind = "PT", label = "Bradycardia", values = list())
    ),
    n_rows_total = 2L
  )
  expect_equal(infer(ctx_soc), "AE")

  # ICH/CSR id numbering when title has no lexical cues.
  ctx_id <- ksAI:::new_ks_context(
    id = "14-6.03",
    type = "Table",
    title = "Результаты анализа",
    rows = list(),
    n_rows_total = 0L
  )
  expect_equal(infer(ctx_id), "LB")

  # Bare "baseline" must not force DM (efficacy change-from-baseline).
  ctx_bl <- ksAI:::new_ks_context(
    id = "14-3.99",
    type = "Table",
    title = "ADAS-Cog change from baseline",
    rows = list(),
    n_rows_total = 0L
  )
  expect_equal(infer(ctx_bl), "EFFC")

  # enrich_context(domain=) overrides everything.
  ctx_ann <- enrich_context(ctx_id, annotations = list(domain = "CUSTOM"))
  expect_equal(infer(ctx_ann), "CUSTOM")

  # domain_map option: exact id then regex.
  old <- ks_set_option(domain_map = c(
    "my-vs" = "VS",
    "^табл-ндя" = "AE"
  ))
  on.exit(ks_set_option(!!!old), add = TRUE)
  expect_equal(
    infer(ksAI:::new_ks_context(id = "my-vs", type = "Table", title = "x")),
    "VS"
  )
  expect_equal(
    infer(ksAI:::new_ks_context(id = "табл-ндя-02", type = "Table", title = "x")),
    "AE"
  )
})

test_that("small LLM can resolve UNKNOWN domains (mocked chat)", {
  opaque <- ksAI:::new_ks_context(
    id = "custom-xyz",
    type = "Table",
    title = "Сводная таблица показателей",
    rows = list(
      list(kind = "detail", cells = list(ROW_LABEL = "Item A"), section = NA_character_)
    ),
    n_rows_total = 1L
  )
  expect_equal(ksAI:::.capsule_infer_domain(opaque), "UNKNOWN")

  fake_chat <- list(
    chat = function(prompt) '{"domain":"VS","confidence":0.91}'
  )
  expect_equal(
    ksAI:::.capsule_infer_domain(
      opaque,
      chat = fake_chat,
      llm_domain = "unknown",
      llm_min_confidence = 0.5
    ),
    "VS"
  )

  # Low confidence rejected.
  weak <- list(chat = function(prompt) '{"domain":"LB","confidence":0.1}')
  expect_equal(
    ksAI:::.capsule_infer_domain(
      opaque,
      chat = weak,
      llm_domain = "unknown",
      llm_min_confidence = 0.5
    ),
    "UNKNOWN"
  )

  # Annotation still wins over LLM.
  ann <- enrich_context(opaque, annotations = list(domain = "DM"))
  expect_equal(
    ksAI:::.capsule_infer_domain(ann, chat = fake_chat, llm_domain = "always"),
    "DM"
  )

  # as_capsules(..., model=) uses mocked chat factory once per call.
  testthat::local_mocked_bindings(
    .make_domain_llm_chat = function(...) {
      list(chat = function(prompt) '{"domain":"EX","confidence":0.88}')
    }
  )
  store <- as_capsules(opaque, model = "tiny-domain", llm_domain = "unknown")
  expect_true(length(store$capsules) > 0)
  expect_true(all(vapply(store$capsules, function(c) c$domain, character(1)) == "EX"))
})

test_that("ks_annotate re-tags UNKNOWN domains with mocked LLM", {
  opaque <- ksAI:::new_ks_context(
    id = "custom-xyz",
    type = "Table",
    title = "Сводная таблица показателей",
    rows = list(
      list(kind = "detail", cells = list(ROW_LABEL = "Item A"), section = NA_character_)
    ),
    n_rows_total = 1L
  )
  store <- as_capsules(opaque)
  expect_true(all(vapply(store$capsules, function(c) c$domain, character(1)) == "UNKNOWN"))

  testthat::local_mocked_bindings(
    .make_domain_llm_chat = function(...) {
      list(chat = function(prompt) '{"domain":"AE","confidence":0.95}')
    },
    .annotate_llm = function(store, ...) store
  )
  out <- ks_annotate(store, model = "tiny-domain")
  expect_true(all(vapply(out$capsules, function(c) c$domain, character(1)) == "AE"))
})

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
