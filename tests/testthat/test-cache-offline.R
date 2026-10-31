test_that("cached provider results can be reproduced offline without requests", {
  cache <- tempfile("sci-cache-")
  on.exit(unlink(cache, recursive=TRUE),add=TRUE)
  fixture <- tibble::tibble(id="synthetic-provider-fixture")
  calls <- 0L
  local_mocked_bindings(.fetch_openalex_remote=function(...) {calls <<- calls+1L; fixture}, sci_rate_limit=function(...) invisible(NULL))
  result <- fetch_openalex(entity="works",search="fixture",cache_dir=cache)
  expect_identical(result,fixture)
  expect_equal(calls,1L)
  files <- list.files(cache,full.names=TRUE)
  expect_length(files,1L)
  Sys.setFileTime(files,Sys.time()-3600*24*30)
  expect_message(again <- fetch_openalex(entity="works",search="fixture",cache_dir=cache,offline=TRUE),"without network")
  expect_identical(again,fixture)
  expect_equal(calls,1L)
  expect_error(fetch_openalex(entity="works",search="different",cache_dir=cache,offline=TRUE),"cache missing")
  expect_equal(calls,1L)
})

test_that("missing and unreadable offline caches fail without creating provider data", {
  cache <- tempfile("missing-cache-")
  local_mocked_bindings(.fetch_openalex_remote=function(...) stop("network must not run"))
  expect_error(fetch_openalex(cache_dir=cache,offline=TRUE),"cache missing")
  expect_false(dir.exists(cache))
  dir.create(cache); on.exit(unlink(cache,recursive=TRUE),add=TRUE)
  writeLines("corrupt",file.path(cache,paste0(rlang::hash(list()),".rds")))
  expect_error(fetch_openalex(cache_dir=cache,offline=TRUE),"unreadable")
})

test_that("cache control arguments are checked", {
  expect_error(fetch_openalex(cache_days=-1),"cache_days")
  expect_error(fetch_openalex(offline=NA),"offline")
  expect_error(fetch_openalex(cache_dir=character()),"cache_dir")
})

test_that("exhausted provider HTTP warnings cannot become empty successful datasets", {
  cache <- tempfile("sci-stale-cache-")
  dir.create(cache)
  on.exit(unlink(cache, recursive=TRUE), add=TRUE)
  fixture <- tibble::tibble(id="preserved-corpus")
  file <- file.path(cache,paste0(rlang::hash(list(entity="works")),".rds"))
  saveRDS(fixture,file)
  Sys.setFileTime(file,Sys.time()-3600*24*30)
  calls <- 0L
  local_mocked_bindings(.fetch_openalex_remote=function(...) {
    calls <<- calls+1L
    warning(structure(list(message="HTTP status 429: retries exhausted",call=NULL),
                      class=c("openalexR_http_warning","warning","condition")))
    tibble::tibble()
  },sci_rate_limit=function(...) invisible(NULL))
  expect_error(fetch_openalex(entity="works",cache_dir=cache),
               class="scientometrics_provider_unavailable")
  expect_identical(readRDS(file),fixture)
  expect_equal(calls,1L)
  expect_length(list.files(cache),1L)
})
