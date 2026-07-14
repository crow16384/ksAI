test_that(".build_compact_index renders a markdown table", {
  dir <- make_fixture_study(n_tables = 2L)
  study <- load_study(dir)
  idx <- ksAI:::.build_compact_index(study)
  expect_match(idx, "| ID | Title | Type | Population | Rows |", fixed = TRUE)
  expect_match(idx, "14-3.01", fixed = TRUE)
})

test_that("small studies embed contexts and register no tools", {
  dir <- make_fixture_study(n_tables = 2L)
  study <- load_study(dir)
  old <- ks_set_option(study_threshold = 100L)
  on.exit(ks_set_option(!!!old), add = TRUE)

  chat <- ks_chat(study, model = "gpt-4o-mini", provider = "openai",
                  credentials = function() "sk-dummy")
  expect_true(is_kschat(chat))
  expect_equal(chat$mode, "small")
  expect_length(chat$chat$get_tools(), 0L)
  expect_match(chat$chat$get_system_prompt(), "14-3.01", fixed = TRUE)
})

test_that("large studies register the navigation tools", {
  dir <- make_fixture_study(n_tables = 3L)
  study <- load_study(dir)
  old <- ks_set_option(study_threshold = 1L)
  on.exit(ks_set_option(!!!old), add = TRUE)

  chat <- ks_chat(study, model = "gpt-4o-mini", provider = "openai",
                  credentials = function() "sk-dummy")
  expect_equal(chat$mode, "large")
  tool_names <- names(chat$chat$get_tools())
  expect_setequal(
    tool_names,
    c("list_tables", "get_table_context", "get_table_data",
      "search_tables", "compare_tables", "get_study_index")
  )
})

test_that("ks_chat rejects unknown providers and non-studies", {
  dir <- make_fixture_study(n_tables = 1L)
  study <- load_study(dir)
  expect_error(
    ks_chat(study, model = "m", provider = "not-a-provider"),
    "provider"
  )
  expect_error(ks_chat(list(), model = "m"), "ks_study")
})

test_that("study-navigation tools return expected content", {
  dir <- make_fixture_study(n_tables = 2L)
  study <- load_study(dir)
  expect_match(ksAI:::.tool_list_tables(study), "14-3.01", fixed = TRUE)
  expect_match(ksAI:::.tool_get_table_data(study, "14-3.01", 2L), "| section |", fixed = TRUE)
  expect_match(ksAI:::.tool_compare_tables(study, "14-3.01", "14-3.02"), "Comparison", fixed = TRUE)
  expect_match(ksAI:::.tool_get_table_context(study, "14-3.01"), "\"id\"", fixed = TRUE)
})
