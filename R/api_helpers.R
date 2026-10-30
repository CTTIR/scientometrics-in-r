#' Fetch works from OpenAlex with caching
#'
#' Wraps [openalexR::oa_fetch()] with local file caching so repeated
#' builds do not re-query the API.
#'
#' @param ... Arguments passed to [openalexR::oa_fetch()].
#' @param cache_dir Directory for cached results.
#' @param cache_days Non-negative days before cache expires; `Inf` never expires.
#' @param offline Use an existing cache without any provider request, even if
#'   stale. Defaults to whether `SCIENTOMETRICS_OFFLINE=1`. Missing or unreadable
#'   caches fail explicitly; no synthetic/provider substitute is returned.
#' @return A tibble of OpenAlex works.
#' @export
fetch_openalex <- function(..., cache_dir = "_freeze/openalex_cache",
                           cache_days = 7,
                           offline = identical(Sys.getenv("SCIENTOMETRICS_OFFLINE"), "1")) {
  if (!is.character(cache_dir) || length(cache_dir) != 1L || is.na(cache_dir) || !nzchar(cache_dir)) {
    stop("`cache_dir` must be one nonempty path.", call. = FALSE)
  }
  if (!is.numeric(cache_days) || length(cache_days) != 1L || is.na(cache_days) || cache_days < 0) {
    stop("`cache_days` must be non-negative or Inf.", call. = FALSE)
  }
  if (!is.logical(offline) || length(offline) != 1L || is.na(offline)) {
    stop("`offline` must be TRUE or FALSE.", call. = FALSE)
  }
  args <- list(...)
  cache_file <- file.path(cache_dir, paste0(rlang::hash(args), ".rds"))
  if (file.exists(cache_file)) {
    age <- as.numeric(difftime(Sys.time(), file.mtime(cache_file), units = "days"))
    if (offline || (!is.na(age) && age < cache_days)) {
      cached <- tryCatch(readRDS(cache_file), error = function(e) {
        stop("OpenAlex cache is unreadable; preserve it and obtain a verified replacement: ", cache_file, call. = FALSE)
      })
      if (offline) message("Using existing OpenAlex cache without network: ", cache_file)
      return(cached)
    }
  }
  if (offline) stop("Offline OpenAlex cache missing for these exact arguments: ", cache_file, call. = FALSE)
  if (!dir.exists(cache_dir) && !dir.create(cache_dir, recursive = TRUE)) {
    stop("Cannot create OpenAlex cache directory.", call. = FALSE)
  }

  max_tries <- 3L
  result <- NULL
  for (attempt in seq_len(max_tries)) {
    sci_rate_limit()
    result <- tryCatch(.fetch_openalex_remote(...), error = function(e) {
      if (attempt == max_tries) stop(e)
      NULL
    })
    if (!is.null(result) && NROW(result) > 0) break
    if (attempt < max_tries) Sys.sleep(2 * attempt)
  }
  if (!is.null(result) && NROW(result) > 0) {
    pending <- tempfile("openalex-", tmpdir = cache_dir)
    on.exit(unlink(pending), add = TRUE)
    saveRDS(result, pending)
    if (!file.rename(pending, cache_file)) {
      stop("Could not atomically replace the OpenAlex cache; existing cache retained.", call. = FALSE)
    }
  }
  result
}

.fetch_openalex_remote <- function(...) openalexR::oa_fetch(...)

# Rate-limiting state shared across calls within a session
.sci_rate_env <- new.env(parent = emptyenv())
.sci_rate_env$last_request <- NULL

#' Enforce rate limiting between API requests
#'
#' Sleeps if the last request was made less than `min_interval` seconds ago.
#' Called internally by [fetch_openalex()].
#'
#' @param min_interval Minimum seconds between requests (default 0.2).
#' @return Invisible NULL.
#' @keywords internal
sci_rate_limit <- function(min_interval = 0.2) {
  now <- proc.time()[["elapsed"]]
  if (!is.null(.sci_rate_env$last_request)) {
    elapsed <- now - .sci_rate_env$last_request
    if (elapsed < min_interval) {
      Sys.sleep(min_interval - elapsed)
    }
  }
  .sci_rate_env$last_request <- proc.time()[["elapsed"]]
  invisible(NULL)
}
