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
  expect_match(ksAI:::.tool_get_table_context(study, "14-3.01"), "Placebo (N=79)", fixed = TRUE)
})

test_that("ask() passes the raw question through when no id is given", {
  dir <- make_fixture_study(n_tables = 2L)
  study <- load_study(dir)
  ks <- structure(
    list(chat = list(chat = function(p) p), study = study),
    class = c("kschat", "list")
  )
  expect_equal(ask(ks, "What is the trend?"), "What is the trend?")
})

test_that("ask(id=) spotlights one table while keeping the study session", {
  dir <- make_fixture_study(n_tables = 2L)
  study <- load_study(dir)
  # The fake session echoes the prompt so we can inspect what was sent.
  ks <- structure(
    list(chat = list(chat = function(p) p), study = study),
    class = c("kschat", "list")
  )
  out <- ask(ks, "Is this consistent?", id = "14-3.01")
  # The spotlighted table is rendered inline with human labels...
  expect_match(out, "Placebo (N=79)", fixed = TRUE)
  # ...framed to keep the rest of the study in scope, with the question appended.
  expect_match(out, "taking the rest of the", fixed = TRUE)
  expect_match(out, "Question: Is this consistent?", fixed = TRUE)
})

test_that("ask(id=) errors on an unknown output id", {
  dir <- make_fixture_study(n_tables = 1L)
  study <- load_study(dir)
  ks <- structure(
    list(chat = list(chat = function(p) p), study = study),
    class = c("kschat", "list")
  )
  expect_error(ask(ks, "q", id = "no-such-id"), "not found")
})
