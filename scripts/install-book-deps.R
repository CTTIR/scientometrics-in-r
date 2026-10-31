#!/usr/bin/env Rscript

# Run from any directory with Rscript --vanilla scripts/install-book-deps.R.
# This installs current CRAN packages, not the versions in historical renv.lock.
# --check: inspect/load installed packages without installing or using the network.
# --list: print the selected inventory without inspecting/installing packages.
# --include-optional: also install backends used only in unevaluated examples.
# --library=/path/to/library: use an explicit library (created only when installing).
# --repos=https://...: select a CRAN-compatible repository for installation.
# Pandoc is required separately; PDF output also needs XeLaTeX/TinyTeX.
# Optional Python examples need a separately configured Python environment.

args <- commandArgs(trailingOnly = TRUE)
allowed <- c("--check", "--list", "--include-optional", "--help")
unknown <- args[!args %in% allowed & !grepl("^--(library|repos)=.+$", args)]
if (length(unknown)) stop("Unknown option(s): ", paste(unknown, collapse = ", "))
if ("--help" %in% args) {
  cat(paste(
    "Usage: Rscript --vanilla scripts/install-book-deps.R [options]",
    "  --check             Check package loading; do not install or use the network",
    "  --list              Print the selected package inventory only",
    "  --include-optional  Include backends from unevaluated examples/exercises",
    "  --library=PATH      Select an R package library",
    "  --repos=URL         Select a CRAN-compatible repository",
    "",
    "Installs current packages; does not restore or certify historical renv.lock.",
    "Pandoc, PDF/LaTeX tools, and optional Python services are separate prerequisites.",
    sep = "\n"
  ), "\n")
  quit(status = 0L)
}
if (all(c("--check", "--list") %in% args)) {
  stop("Choose either --check or --list.")
}
option_value <- function(name, default) {
  values <- sub(paste0("^--", name, "="), "",
                args[startsWith(args, paste0("--", name, "="))])
  if (length(values) > 1L) stop("Specify --", name, " only once.")
  if (length(values)) values else default
}

script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(script_arg) != 1L) stop("Run this installer with Rscript --vanilla.")
script_path <- normalizePath(sub("^--file=", "", script_arg), mustWork = TRUE)
repo <- dirname(dirname(script_path))
description <- read.dcf(file.path(repo, "DESCRIPTION"))
companion_deps <- trimws(unlist(strsplit(
  paste(description[1L, intersect(c("Depends", "Imports"), colnames(description))],
        collapse = ","), ",", fixed = TRUE
)))
companion_deps <- sub("[[:space:]]*\\(.*\\)$", "", companion_deps)
companion_deps <- setdiff(companion_deps, c("", "R"))

# Direct requirements of evaluated chunks in _bookdown.yml, their sourced R
# helpers, and the configured bookdown output formats. Keep these explicit so
# a package used by a chapter is not supplied accidentally by another Suggests.
book_deps <- c(
  # Rendering and formatted output.
  "bookdown", "rmarkdown", "knitr", "bslib", "downlit", "xml2", "sessioninfo",
  "gt", "glue", "here", "scales", "patchwork", "jsonlite", "yaml", "fs", "systemfonts",
  "zip", "digest",
  # Corpus acquisition, import, storage, and wrangling.
  "tidyverse", "openalexR", "rcrossref", "bib2df", "RefManageR",
  "bibliometrix", "arrow", "stringdist", "pdftools", "reshape2",
  # Networks, text analysis, embeddings, and statistical models.
  "igraph", "tidygraph", "ggraph", "visNetwork", "quanteda",
  "quanteda.textstats", "stopwords", "tidytext", "topicmodels", "stm",
  "word2vec", "uwot", "broom",
  # Interactive examples whose setup chunks are evaluated.
  "plotly", "DT", "shiny"
)

# These occur only in eval:false code, including the exercise-solutions appendix.
# Installing them does not provision PostgreSQL, OCR language data, a Quarto CLI,
# a deployment account, downloaded NLP models, or a Python environment.
optional_deps <- c(
  "DBI", "RPostgres", "tesseract", "quarto", "renv", "targets",
  "reticulate", "rsconnect", "udpipe", "umap", "cachem", "colorBlindness",
  "crosstalk", "ggrepel", "httr2", "janitor", "lubridate", "memoise", "slam"
)
required <- sort(unique(c(book_deps, companion_deps)))
optional_deps <- sort(setdiff(optional_deps, required))
packages <- if ("--include-optional" %in% args) {
  c(required, optional_deps)
} else required
if ("--list" %in% args) {
  write.table(data.frame(
    package = packages,
    scope = ifelse(packages %in% required, "book/companion", "optional example")
  ), row.names = FALSE, quote = FALSE, sep = "\t")
  quit(status = 0L)
}

library_path <- path.expand(option_value("library", .libPaths()[1L]))
checking <- "--check" %in% args
if (!dir.exists(library_path)) {
  if (checking) stop("Library does not exist: ", library_path)
  if (!dir.create(library_path, recursive = TRUE)) {
    stop("Cannot create library: ", library_path)
  }
}
.libPaths(c(library_path, .libPaths()))
if (!checking) {
  if (file.access(library_path, 2L) != 0L) {
    stop("Library is not writable; supply --library=PATH: ", library_path)
  }
  missing <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing)) {
    repos <- option_value("repos", "https://cloud.r-project.org")
    message("Installing ", length(missing), " packages into ", library_path)
    # NA installs Depends, Imports, and LinkingTo, without every package's Suggests.
    utils::install.packages(missing, lib = library_path, repos = repos,
                            dependencies = NA)
  }
}

# install.packages can warn and return normally after an installation failure.
# Loading every selected namespace makes those failures produce a nonzero exit.
loadable <- vapply(packages, requireNamespace, logical(1), quietly = TRUE)
versions <- vapply(packages, function(package) {
  if (loadable[[package]]) as.character(utils::packageVersion(package)) else "MISSING"
}, character(1))
write.table(data.frame(package = packages, version = versions),
            row.names = FALSE, quote = FALSE, sep = "\t")
if (any(!loadable)) {
  stop("Packages cannot be loaded: ", paste(packages[!loadable], collapse = ", "),
       ". Run the installer without --check after satisfying system prerequisites.")
}
message("All ", length(packages), " selected package namespaces load successfully.")
