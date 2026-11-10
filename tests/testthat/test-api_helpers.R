test_that("fetch_openalex caches results", {
  skip_on_cran()
  skip_if_offline("api.openalex.org")
  skip_if_not_installed("openalexR")

  cache_dir <- file.path(tempdir(), "test_openalex_cache")
  on.exit(unlink(cache_dir, recursive = TRUE), add = TRUE)

  expect_true(!dir.exists(cache_dir))

  result <- tryCatch(
    fetch_openalex(
      entity = "works",
      search = "bibliometrics",
      options = list(sample = 5, seed = 1),
      cache_dir = cache_dir,
      cache_days = 1
    ),
    error = function(e) NULL
  )

  skip_if(is.null(result), "OpenAlex API unavailable")

  expect_true(dir.exists(cache_dir))
  cache_files <- list.files(cache_dir, pattern = "\\.rds$")
  expect_length(cache_files, 1)

  result2 <- fetch_openalex(
    entity = "works",
    search = "bibliometrics",
    options = list(sample = 5, seed = 1),
    cache_dir = cache_dir,
    cache_days = 1
  )
  expect_identical(result, result2)
})
