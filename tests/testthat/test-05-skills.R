test_that(".fill_prompt replaces named placeholders", {
  tmpl <- "Hello {{name}}, id {{id}}."
  out <- ksAI:::.fill_prompt(tmpl, name = "world", id = "14-3.01")
  expect_equal(out, "Hello world, id 14-3.01.")
})

test_that(".fill_prompt requires named substitutions", {
  expect_error(ksAI:::.fill_prompt("x {{a}}", "unnamed"), "named")
})

test_that("built-in skills resolve and load", {
  for (skill in c("describe", "summarize", "csr_section", "review")) {
    path <- ksAI:::.resolve_skill_path(skill)
    expect_true(file.exists(path))
    expect_gt(nchar(ksAI:::.load_prompt(skill)), 0)
  }
})

test_that("ks_list_skills lists only user-facing built-in skills", {
  skills <- ks_list_skills()
  expect_setequal(skills$name, c("describe", "summarize", "csr_section", "review"))
  expect_false("system" %in% skills$name)
  expect_false("system_single" %in% skills$name)
})

test_that("user skills_dir shadows built-ins and adds new skills", {
  udir <- tempfile("skills_")
  dir.create(udir)
  writeLines("custom {{context}}", file.path(udir, "my_intro.md"))
  writeLines("overridden describe {{context}}", file.path(udir, "describe.md"))

  old <- ks_set_option(skills_dir = udir)
  on.exit(ks_set_option(!!!old), add = TRUE)

  skills <- ks_list_skills()
  expect_true("my_intro" %in% skills$name)
  d <- skills[skills$name == "describe", ]
  expect_equal(d$source, "user")
  expect_match(ksAI:::.load_prompt("describe"), "overridden")
})

test_that("unknown skill raises a clear error", {
  expect_error(ksAI:::.resolve_skill_path("no_such_skill"), "not found")
})

test_that(".render_contexts renders labelled markdown blocks by default", {
  dir <- make_fixture_study(n_tables = 2L)
  study <- ks_load(dir, ids = c("14-3.01", "14-3.02"))
  contexts <- list(
    "14-3.01" = study[["14-3.01"]],
    "14-3.02" = study[["14-3.02"]]
  )

  out <- ksAI:::.render_contexts(contexts, format = "markdown")
  expect_match(out, "### Output 14-3.01", fixed = TRUE)
  expect_match(out, "### Output 14-3.02", fixed = TRUE)
})

test_that(".render_contexts uses compact separators", {
  dir <- make_fixture_study(n_tables = 2L)
  study <- ks_load(dir, ids = c("14-3.01", "14-3.02"))
  contexts <- list(
    "14-3.01" = study[["14-3.01"]],
    "14-3.02" = study[["14-3.02"]]
  )
  out <- ksAI:::.render_contexts(contexts, format = "compact")
  expect_match(out, "---", fixed = TRUE)
  expect_match(out, "TABLE: 14-3.01", fixed = TRUE)
  expect_false(grepl("### Output", out, fixed = TRUE))
})

test_that("ks_llm context_format compact injects as_compact text", {
  dir <- make_fixture_study(n_tables = 1L)
  study <- ks_load(dir, ids = "14-3.01")

  captured <- NULL
  fake_chat <- list(chat = function(p) {
    captured <<- p
    "ok"
  })

  testthat::local_mocked_bindings(
    .resolve_chat_session = function(...) {
      list(chat = fake_chat, study = study, model = "m", provider = "ollama")
    }
  )

  ks_llm(study, ids = "14-3.01", skill = "describe", context_format = "compact")
  expect_match(captured, "TABLE: 14-3.01", fixed = TRUE)
  expect_false(grepl("\\| --- \\|", captured))
})

test_that("ks_llm defaults to markdown context format", {
  dir <- make_fixture_study(n_tables = 1L)
  study <- ks_load(dir, ids = "14-3.01")

  captured <- NULL
  fake_chat <- list(chat = function(p) {
    captured <<- p
    "ok"
  })

  testthat::local_mocked_bindings(
    .resolve_chat_session = function(...) {
      list(chat = fake_chat, study = study, model = "m", provider = "ollama")
    }
  )

  ks_llm(study, ids = "14-3.01", skill = "describe")
  expect_match(captured, "**ID**:", fixed = TRUE)
})

test_that("ks_llm returns ks_result for describe and appends user prompt", {
  dir <- make_fixture_study(n_tables = 1L)
  study <- ks_load(dir, ids = "14-3.01")

  captured <- NULL
  fake_chat <- list(chat = function(p) {
    captured <<- p
    "ok"
  })

  testthat::local_mocked_bindings(
    .resolve_chat_session = function(...) {
      list(chat = fake_chat, study = study, model = "m", provider = "ollama")
    }
  )

  out <- ks_llm(
    study,
    ids = "14-3.01",
    skill = "describe",
    prompt = "Please answer in Spanish"
  )

  expect_true(is_ks_result(out))
  expect_equal(out$ids, "14-3.01")
  expect_equal(out$skill, "describe")
  expect_match(out$response, "## 14-3.01", fixed = TRUE)
  expect_match(captured, "Additional user request", fixed = TRUE)
  expect_match(captured, "Please answer in Spanish", fixed = TRUE)
})

test_that("ks_llm describe supports multiple IDs", {
  dir <- make_fixture_study(n_tables = 2L)
  study <- ks_load(dir, ids = c("14-3.01", "14-3.02"))

  calls <- 0L
  fake_chat <- list(chat = function(p) {
    calls <<- calls + 1L
    paste0("answer-", calls)
  })

  testthat::local_mocked_bindings(
    .resolve_chat_session = function(...) {
      list(chat = fake_chat, study = study, model = "m", provider = "ollama")
    }
  )

  out <- ks_llm(study, ids = c("14-3.01", "14-3.02"), skill = "describe")
  expect_match(out$response, "## 14-3.01", fixed = TRUE)
  expect_match(out$response, "## 14-3.02", fixed = TRUE)
  expect_equal(calls, 2L)
})

test_that("ks_llm review requires exactly two IDs", {
  dir <- make_fixture_study(n_tables = 1L)
  study <- ks_load(dir, ids = "14-3.01")

  fake_chat <- list(chat = function(p) p)
  testthat::local_mocked_bindings(
    .resolve_chat_session = function(...) {
      list(chat = fake_chat, study = study, model = "m", provider = "ollama")
    }
  )

  expect_error(ks_llm(study, ids = "14-3.01", skill = "review"), "exactly two IDs")
})

test_that("ks_llm accepts free prompt with multiple IDs", {
  dir <- make_fixture_study(n_tables = 2L)
  study <- ks_load(dir, ids = c("14-3.01", "14-3.02"))

  fake_chat <- list(chat = function(p) p)
  testthat::local_mocked_bindings(
    .resolve_chat_session = function(...) {
      list(chat = fake_chat, study = study, model = "m", provider = "ollama")
    }
  )

  out <- ks_llm(
    study,
    ids = c("14-3.01", "14-3.02"),
    skill = NULL,
    prompt = "Compare these tables"
  )

  expect_true(is_ks_result(out))
  expect_match(out$response, "### Output 14-3.01", fixed = TRUE)
  expect_match(out$response, "### Output 14-3.02", fixed = TRUE)
  expect_match(out$response, "User request:", fixed = TRUE)
})

test_that("ks_llm prepends prior analysis when prior result is provided", {
  dir <- make_fixture_study(n_tables = 1L)
  study <- ks_load(dir, ids = "14-3.01")

  fake_chat <- list(chat = function(p) p)
  testthat::local_mocked_bindings(
    .resolve_chat_session = function(...) {
      list(chat = fake_chat, study = study, model = "m", provider = "ollama")
    }
  )

  prior <- ksAI:::new_ks_result(
    ids = "14-3.01",
    skill = "describe",
    prompt = NULL,
    response = "Old analysis",
    model = "m",
    provider = "ollama"
  )

  out <- ks_llm(study, ids = "14-3.01", skill = "describe", prior = prior)
  expect_match(out$response, "Prior analysis:", fixed = TRUE)
  expect_match(out$response, "Old analysis", fixed = TRUE)
})
