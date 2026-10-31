suppressPackageStartupMessages({
  library(rmarkdown)
  library(fs)
  library(bookdown)
})

# Source the project-wide knitr/ggplot setup so chunk options, theme,
# AND the mermaid engine registration are in place for every per-chapter
# render. bookdown's full-book render does this via before_chapter_script;
# rmarkdown::render() doesn't, so we do it here once.
source("_common.R", local = FALSE)
repo_root <- normalizePath(".", mustWork = TRUE)

chapters <- c(
  dir_ls("chapters",     glob = "*.Rmd"),
  dir_ls("case-studies", glob = "*.Rmd"),
  dir_ls("appendices",   glob = "*.Rmd")
)
chapters <- chapters[!grepl("_template\\.Rmd$", chapters)]

out_dir <- "docs/pdf-chapters"
dir_create(out_dir)

# bookdown::pdf_document2 supports the \@ref() cross-references that
# plain rmarkdown::pdf_document leaves as literal \@ref text — pdflatex
# then fails with "Undefined control sequence" on every chapter that
# references a figure or table. pdf_document2 also keeps the book's
# LaTeX preamble (tcolorbox box envs, hyperref, fontspec fallback).
#
# Resolve the preamble path absolutely. When rendering chapters/NN-*.Rmd
# pandoc otherwise looks for chapters/style/preamble.tex.
preamble_path <- normalizePath("style/preamble.tex", mustWork = TRUE)
pdf_fmt <- bookdown::pdf_document2(
  latex_engine = "xelatex",
  includes     = rmarkdown::includes(in_header = preamble_path),
  toc          = FALSE,
  number_sections = FALSE
)

failed <- character()
for (ch in chapters) {
  out_file <- path_ext_set(path_file(ch), "pdf")
  message("Rendering: ", ch, " -> ", out_file)
  ok <- tryCatch({
    rmarkdown::render(
      input         = ch,
      output_format = pdf_fmt,
      output_file   = out_file,
      output_dir    = out_dir,
      knit_root_dir = repo_root,
      envir         = new.env(),
      quiet         = TRUE
    )
    TRUE
  }, error = function(e) {
    message("FAILED: ", ch, " — ", conditionMessage(e))
    FALSE
  })
  if (!isTRUE(ok)) failed <- c(failed, ch)
}

if (length(failed)) {
  message("\n", length(failed), " of ", length(chapters), " chapter PDFs failed:")
  message(paste("  -", failed, collapse = "\n"))
  quit(status = 1)
} else {
  message("All ", length(chapters), " chapter PDFs rendered cleanly.")
}
