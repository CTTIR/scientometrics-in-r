# Setup must replay package/option side effects when a fresh process uses caches.
repo <- normalizePath(".", mustWork = TRUE)
workspace <- tempfile("book-setup-cache-")
dir.create(workspace)
source_file <- file.path(workspace, "probe.Rmd")
writeLines(c(
  "```{r init, include=FALSE, cache=FALSE}",
  sprintf("knitr::opts_knit$set(root.dir = %s)", deparse(repo)),
  sprintf("source(%s, chdir = TRUE)", deparse(file.path(repo, "_common.R"))),
  sprintf("knitr::opts_chunk$set(error = FALSE, cache.path = %s)", deparse(paste0(workspace, "/cache/"))),
  "```", "",
  "```{r probe-setup, cache=TRUE}",
  "options(book_setup_probe = 'loaded')",
  "```", "",
  "```{r verify, cache=FALSE}",
  "stopifnot(identical(getOption('book_setup_probe'), 'loaded'))",
  "```"
), source_file)
for (i in 1:2) {
  expr <- sprintf("knitr::knit(%s, output = %s, quiet = TRUE)",
                  deparse(source_file), deparse(file.path(workspace, paste0("pass-", i, ".md"))))
  status <- system2(file.path(R.home("bin"), "Rscript"), c("--vanilla", "-e", shQuote(expr)))
  if (!identical(status, 0L)) stop("Setup side effects were lost on pass ", i)
}
unlink(workspace, recursive = TRUE)
cat("Setup side effects replayed in two independent render processes.\n")
