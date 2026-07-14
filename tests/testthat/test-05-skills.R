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

test_that("ks_list_skills lists the built-in skills without infrastructure prompts", {
  skills <- ks_list_skills()
  expect_setequal(skills$name, c("describe", "summarize", "csr_section", "review"))
  expect_false("system" %in% skills$name)
  expect_false("study_index" %in% skills$name)
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
  # describe now sourced from the user dir
  d <- skills[skills$name == "describe", ]
  expect_equal(d$source, "user")
  expect_match(ksAI:::.load_prompt("describe"), "overridden")
})

test_that("unknown skill raises a clear error", {
  expect_error(ksAI:::.resolve_skill_path("no_such_skill"), "not found")
})

test_that(".concat_contexts wraps multiple contexts as a JSON array", {
  dir <- make_fixture_study(n_tables = 2L)
  study <- load_study(dir)
  out <- ksAI:::.concat_contexts(study$tables)
  parsed <- jsonlite::fromJSON(out, simplifyVector = FALSE)
  expect_length(parsed, 2L)
})

test_that("ks_list_skills excludes the focused single-output prompt", {
  skills <- ks_list_skills()
  expect_false("system_single" %in% skills$name)
})

test_that(".assemble_skill_prompt fills context and id placeholders", {
  out <- ksAI:::.assemble_skill_prompt(
    "id={{id}} ctx={{context}}",
    context = "TBL", id = "X1"
  )
  expect_equal(out, "id=X1 ctx=TBL")
  # A NULL id becomes an empty string rather than erroring.
  out2 <- ksAI:::.assemble_skill_prompt("[{{id}}]", context = "c", id = NULL)
  expect_equal(out2, "[]")
})

test_that("single-id skill context is the rendered table, not whole-study JSON", {
  dir <- make_fixture_study(n_tables = 3L)
  study <- load_study(dir)
  ks <- structure(
    list(chat = NULL, study = study, mode = "small", provider = "ollama",
         model = "m", base_url = NULL, echo = "none", dots = list()),
    class = c("kschat", "list")
  )
  # Avoid constructing a real ellmer/ollama session in tests.
  testthat::local_mocked_bindings(.make_focused_chat = function(ks) list(chat = identity))

  resolved <- ksAI:::.resolve_chat_and_context(ks, chat = NULL, id = "14-3.01")

  # Rendered Markdown for the single table (human label present)...
  expect_true(grepl("Placebo (N=79)", resolved$context, fixed = TRUE))
  # ...not the whole-study machine JSON, and not the sibling tables.
  expect_false(grepl("\"n_rows_total\"", resolved$context, fixed = TRUE))
  expect_false(grepl("14-3.02", resolved$context, fixed = TRUE))
  expect_equal(resolved$id, "14-3.01")
})

test_that("study-wide skill reuses the session and concatenates JSON", {
  dir <- make_fixture_study(n_tables = 2L)
  study <- load_study(dir)
  sentinel <- list(chat = function(p) p)
  ks <- structure(
    list(chat = sentinel, study = study, mode = "small", provider = "ollama",
         model = "m", base_url = NULL, echo = "none", dots = list()),
    class = c("kschat", "list")
  )

  resolved <- ksAI:::.resolve_chat_and_context(ks, chat = NULL, id = NULL)

  expect_identical(resolved$chat, sentinel)
  parsed <- jsonlite::fromJSON(resolved$context, simplifyVector = FALSE)
  expect_length(parsed, 2L)
  expect_null(resolved$id)
})

test_that("single-id skill on an unknown id raises a clear error", {
  dir <- make_fixture_study(n_tables = 1L)
  study <- load_study(dir)
  ks <- structure(
    list(study = study, provider = "ollama", model = "m", base_url = NULL,
         echo = "none", dots = list()),
    class = c("kschat", "list")
  )
  expect_error(
    ksAI:::.resolve_chat_and_context(ks, chat = NULL, id = "no-such-id"),
    "not found"
  )
})
