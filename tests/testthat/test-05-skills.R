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
