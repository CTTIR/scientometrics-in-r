# Run after rendering: Rscript scripts/build-download-manifest.R
# Inventory actual nonempty artifacts; missing optional outputs get no link.
build_download_manifest <- function(repo_root = ".") {
  repo_root <- normalizePath(repo_root, mustWork = TRUE)
  config <- yaml::read_yaml(file.path(repo_root, "_bookdown.yml"))
  out_dir <- file.path(repo_root, config$output_dir)
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  present <- function(relative_path) {
    info <- file.info(file.path(out_dir, relative_path))
    !is.na(info$size) && !isTRUE(info$isdir) && info$size > 0
  }
  # Chapter downloads are linked from the panel under each chapter title.
  manifest <- list(book = list())
  for (format in c("pdf", "epub")) {
    relative_path <- paste0(config$book_filename, ".", format)
    if (present(relative_path)) manifest$book[[format]] <- relative_path
  }
  destination <- file.path(out_dir, "downloads.json")
  temporary <- tempfile("downloads-", tmpdir = out_dir, fileext = ".json")
  on.exit(unlink(temporary), add = TRUE)
  jsonlite::write_json(manifest, temporary, auto_unbox = TRUE, pretty = TRUE)
  if (!file.rename(temporary, destination)) {
    stop("Could not publish the download inventory.", call. = FALSE)
  }
  message("Download inventory: ", length(manifest$book), " book formats.")
  invisible(manifest)
}

if (sys.nframe() == 0L) build_download_manifest()
