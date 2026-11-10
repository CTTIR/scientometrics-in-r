# Run from the repository root: Rscript scripts/verify-download-manifest.R
source("scripts/build-download-manifest.R")
fixture <- tempfile("download-inventory-")
dir.create(file.path(fixture, "docs"), recursive = TRUE)
tryCatch({
  yaml::write_yaml(list(
    output_dir = "docs", book_filename = "test-book",
    rmd_files = c("index.Rmd", "chapters/01-test.Rmd", "chapters/02-missing.Rmd")
  ), file.path(fixture, "_bookdown.yml"))
  empty <- build_download_manifest(fixture)
  stopifnot(length(empty$book) == 0L, is.null(empty$chapters))

  writeLines("PDF fixture", file.path(fixture, "docs", "test-book.pdf"))
  file.create(file.path(fixture, "docs", "test-book.epub"))
  partial <- build_download_manifest(fixture)
  stopifnot(identical(partial$book$pdf, "test-book.pdf"),
            is.null(partial$book$epub), is.null(partial$chapters))

  unlink(file.path(fixture, "docs", "test-book.pdf"))
  rebuilt <- build_download_manifest(fixture)
  stored <- jsonlite::read_json(file.path(fixture, "docs", "downloads.json"))
  stopifnot(is.null(rebuilt$book$pdf), is.null(stored$book$pdf),
            is.null(stored$chapters))
  cat("Download inventory: 8 checks passed for missing, partial, empty and removed artifacts.\n")
}, finally = unlink(fixture, recursive = TRUE))
