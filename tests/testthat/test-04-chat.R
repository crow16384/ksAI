test_that(".study_context_markdown renders loaded outputs as markdown blocks", {
  dir <- make_fixture_study(n_tables = 2L)
  study <- ks_load(dir, ids = c("14-3.01", "14-3.02"))
  out <- ksAI:::.study_context_markdown(study)

  expect_match(out, "### Output 14-3.01", fixed = TRUE)
  expect_match(out, "### Output 14-3.02", fixed = TRUE)
  expect_match(out, "Placebo (N=79)", fixed = TRUE)
})

test_that("ks_chat creates a targeted session without study-navigation tools", {
  dir <- make_fixture_study(n_tables = 2L)
  study <- ks_load(dir, ids = c("14-3.01", "14-3.02"))

  chat <- ks_chat(
    study,
    model = "gpt-4o-mini",
    provider = "openai",
    credentials = function() "sk-dummy"
  )

  expect_true(is_kschat(chat))
  expect_equal(chat$mode, "targeted")
  expect_length(chat$chat$get_tools(), 0L)
  expect_match(chat$chat$get_system_prompt(), "Loaded output contexts", fixed = TRUE)
})

test_that("ks_chat rejects unknown providers and non-studies", {
  dir <- make_fixture_study(n_tables = 1L)
  study <- ks_load(dir, ids = "14-3.01")

  expect_error(
    ks_chat(study, model = "m", provider = "not-a-provider"),
    "provider"
  )
  expect_error(ks_chat(list(), model = "m"), "ks_study")
})
