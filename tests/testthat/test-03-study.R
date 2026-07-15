test_that("save_study / ks_load round-trip preserves contents", {
  dir <- make_fixture_study(n_tables = 2L, n_rows = 4L)
  study <- ks_load(dir, ids = NULL)

  ks_path <- tempfile(fileext = ".ks")
  save_study(study, ks_path)
  expect_true(file.exists(ks_path))

  study2 <- ks_load(ks_path)
  expect_true(is_ks_study(study2))
  expect_equal(names(study$tables), names(study2$tables))
  expect_equal(
    study[["14-3.01"]]$rows[[1]]$cells,
    study2[["14-3.01"]]$rows[[1]]$cells
  )
  expect_equal(study[["14-3.01"]]$population, study2[["14-3.01"]]$population)
})

test_that("save_study adds the .ks extension", {
  dir <- make_fixture_study(n_tables = 1L)
  study <- ks_load(dir, ids = NULL)
  base <- tempfile()
  out <- save_study(study, base)
  expect_match(out, "\\.ks$")
  expect_true(file.exists(out))
})

test_that("[[ accessor finds outputs by id across all types", {
  dir <- make_fixture_study(n_tables = 2L)
  study <- ks_load(dir, ids = NULL)
  expect_true(is_ks_context(study[["14-3.02"]]))
  expect_null(study[["does-not-exist"]])
})

test_that("save_study rejects non-studies", {
  expect_error(save_study(list(), tempfile()), "ks_study")
})
