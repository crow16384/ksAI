test_that("is_ks_result identifies result objects", {
  out <- ksAI:::new_ks_result(
    ids = c("14-3.01", "14-3.02"),
    skill = "review",
    prompt = "Compare",
    response = "Done",
    model = "m",
    provider = "ollama"
  )

  expect_true(is_ks_result(out))
  expect_false(is_ks_result(list()))
})

test_that("save_result writes markdown and json", {
  out <- ksAI:::new_ks_result(
    ids = c("14-3.01", "14-3.02"),
    skill = "review",
    prompt = "Compare",
    response = "Done",
    model = "m",
    provider = "ollama"
  )

  base <- tempfile("ks_result_")
  paths <- save_result(out, base)

  expect_true(file.exists(paths$md))
  expect_true(file.exists(paths$json))

  md <- paste(readLines(paths$md, warn = FALSE), collapse = "\n")
  expect_match(md, "# ksAI result", fixed = TRUE)
  expect_match(md, "## Response", fixed = TRUE)
})

test_that("load_result round-trips from json", {
  out <- ksAI:::new_ks_result(
    ids = c("14-3.01", "14-3.02"),
    skill = "review",
    prompt = "Compare",
    response = "Done",
    model = "m",
    provider = "ollama"
  )

  base <- tempfile("ks_result_")
  paths <- save_result(out, base)

  loaded <- load_result(paths$json)
  expect_true(is_ks_result(loaded))
  expect_equal(loaded$ids, c("14-3.01", "14-3.02"))
  expect_equal(loaded$skill, "review")
  expect_equal(loaded$response, "Done")
})

test_that("load_result can resolve by base path", {
  out <- ksAI:::new_ks_result(
    ids = "14-3.01",
    skill = "describe",
    prompt = NULL,
    response = "Done",
    model = "m",
    provider = "ollama"
  )

  base <- tempfile("ks_result_")
  save_result(out, base)

  loaded <- load_result(base)
  expect_true(is_ks_result(loaded))
  expect_equal(loaded$ids, "14-3.01")
})
