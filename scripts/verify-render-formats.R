#!/usr/bin/env Rscript

# Run from any directory: Rscript --vanilla /path/to/scripts/verify-render-formats.R
# Uses the book dependencies and PDF fonts documented in README.md. This checks
# format setup and table serialization, not a TeX compilation or API workflow.

args <- commandArgs(trailingOnly = TRUE)
if (identical(args, "--help")) {
  cat("Usage: Rscript --vanilla scripts/verify-render-formats.R\n",
      "Checks PDF, repeated PDF, HTML and EPUB table/device transitions.\n",
      "Requires book dependencies, Cairo and a PDF font from README.md.\n",
      "Does not access credentials, fetch data, or compile TeX.\n", sep = "")
  quit(status = 0L)
}
if (length(args)) stop("This script accepts only --help.", call. = FALSE)

script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(script_arg) != 1L) stop("Run this check with Rscript --vanilla.")
script_path <- normalizePath(sub("^--file=", "", script_arg), mustWork = TRUE)
repo <- dirname(dirname(script_path))

required <- c("knitr", "gt", "rlang", "systemfonts", "dplyr", "rmarkdown", "yaml")
missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) {
  stop("Missing dependencies: ", paste(missing, collapse = ", "),
       ". Run scripts/install-book-deps.R first.", call. = FALSE)
}

# Exercise the actual format-dependent setup without sourcing the credential
# setup, provider helpers or file-copying operations elsewhere in _common.R.
# Locate the condition structurally so unrelated setup additions do not move it.
expressions <- parse(file.path(repo, "_common.R"))
is_format_setup <- vapply(expressions, function(expr) {
  is.call(expr) && identical(expr[[1L]], as.name("if")) &&
    identical(expr[[2L]], quote(knitr::is_latex_output()))
}, logical(1))
if (sum(is_format_setup) != 1L) {
  stop("Expected one top-level PDF format setup in _common.R; update this check if its structure changes.")
}
setup <- expressions[[which(is_format_setup)]]
setup_env <- new.env(parent = globalenv())
check <- function(condition, message) {
  if (!isTRUE(condition)) stop(message, call. = FALSE)
}
active_printer <- function() {
  getS3method("knit_print", "gt_tbl", envir = asNamespace("knitr"))
}
original_printer <- active_printer()
table <- gt::gt(data.frame(label = c("short", "format transition sentinel"),
                          value = c(1, 2)))
as_text <- function(value) paste(value, collapse = "\n")
check_html <- function(value, context) {
  text <- as_text(value)
  check(grepl("<table", text, fixed = TRUE) &&
          grepl("format transition sentinel", text, fixed = TRUE) &&
          !grepl("\\begin{longtable}", text, fixed = TRUE),
        paste(context, "must produce an HTML table, not LaTeX."))
}
setup_pdf <- function() {
  knitr::opts_knit$set(rmarkdown.pandoc.to = "latex")
  eval(setup, envir = setup_env)
  family <- getOption("sci.pdf_family")
  check(is.character(family) && length(family) == 1L && !is.na(family) &&
          nzchar(family), "PDF setup did not select a font.")
  check(identical(knitr::opts_chunk$get("dev"), "cairo_pdf") &&
          identical(knitr::opts_chunk$get("dev.args"), list(family = family)),
        "PDF setup must pass its selected font to the Cairo device.")
  text <- as_text(knitr::knit_print(table))
  check(grepl("\\begin{longtable}", text, fixed = TRUE) &&
          grepl("format transition sentinel", text, fixed = TRUE),
        "PDF setup must produce a LaTeX longtable with the table content.")
}
setup_web <- function(format) {
  knitr::opts_knit$set(rmarkdown.pandoc.to = format)
  eval(setup, envir = setup_env)
  check(identical(active_printer(), original_printer),
        paste(format, "did not restore the original gt printer."))
  check(identical(knitr::opts_chunk$get("dev"), "png") &&
          length(knitr::opts_chunk$get("dev.args")) == 0L,
        paste(format, "retained PDF device arguments."))
  check(is.null(getOption("sci.pdf_family")),
        paste(format, "retained the PDF font option."))
  check_html(knitr::knit_print(table), format)
}

# Do not attach knitr: namespace-only usage must work in a clean Rscript process.
setup_pdf()
setup_pdf()
pdf_printer <- active_printer()
cat("PASS: PDF and repeated PDF setup produce longtables with Cairo font arguments.\n")

# Chapter 21 prints a grouped tibble. Group labels are spanning rows; they must
# not become imaginary selectable columns, while real stub columns need width.
fixture <- data.frame(
  year = c(2019L, 2019L, 2023L),
  author = c("first row label", "second row label", "third row label"),
  term = c("bibliometr", "citation", "collabor"),
  tfidf = c(11.5, 7.5, 9.5), hidden = "hidden column sentinel"
)
grouped <- gt::gt(dplyr::group_by(fixture[c("year", "term", "tfidf")], year)) |>
  gt::fmt_number(columns = tfidf, decimals = 1)
row_labels <- gt::gt(fixture[c("author", "term", "tfidf")], rowname_col = "author")
grouped_hidden <- gt::gt(fixture, rowname_col = "author", groupname_col = "year") |>
  gt::cols_hide(columns = hidden)
cases <- list(grouped = grouped, row_labels = row_labels, grouped_hidden = grouped_hidden)
expected_columns <- c(grouped = 2L, row_labels = 3L, grouped_hidden = 3L)
for (name in names(cases)) {
  text <- as_text(knitr::knit_print(cases[[name]]))
  check(grepl("\\begin{longtable}", text, fixed = TRUE) &&
          all(vapply(fixture$term, grepl, logical(1), x = text, fixed = TRUE)),
        paste(name, "lost table content or failed to produce a longtable."))
  check(!grepl("::group_id::", text, fixed = TRUE) &&
          !grepl("::rowname::", text, fixed = TRUE) &&
          !grepl("hidden column sentinel", text, fixed = TRUE),
        paste(name, "exposed internal group/stub names or hidden data."))
  if (name != "row_labels") {
    check(all(vapply(c("2019", "2023"), grepl, logical(1), x = text, fixed = TRUE)),
          paste(name, "lost its group labels."))
  }
  if (name != "grouped") {
    check(all(vapply(fixture$author, grepl, logical(1), x = text, fixed = TRUE)),
          paste(name, "lost its row labels."))
  }
  # The emitted LaTeX must allocate the full width only to displayed columns.
  matches <- regmatches(text, gregexpr("[0-9]+\\.[0-9]+\\\\linewidth -2", text))[[1L]]
  widths <- as.numeric(sub("\\\\linewidth.*$", "", matches))
  check(length(widths) == expected_columns[[name]] &&
          abs(sum(widths) - 1) <= length(widths) * 0.005 + 1e-8,
        paste(name, "did not allocate the available width to its displayed columns."))
  cat("PASS:", name, "preserves labels/content, excludes hidden data and fits displayed columns.\n")
}

# The metadata comparison contains DOI strings that cannot wrap at spaces.
# Its PDF transformation must preserve every character and existing gt formats.
identifiers <- c("10.1073/pnas.0507655102", "10.1162/qss_a_00112",
                 "https://example.org/record?x=1&y=2#part%20two")
formatted <- gt::gt(data.frame(
  identifier = identifiers, value = c(1.23, 2.34, 3.45),
  markup = c("A **styled** value", "A $x^2$ formula", "[source](https://example.org/record)")
)) |>
  gt::fmt_number(columns = value, decimals = 1) |>
  gt::fmt_markdown(columns = markup) |>
  gt::tab_header(title = "Metadata comparison: OpenAlex vs. Crossref",
                 subtitle = "Same DOIs queried from both sources")
text <- as_text(knitr::knit_print(formatted))
check(all(vapply(paste0("\\nolinkurl{", identifiers, "}"), grepl,
                 logical(1), x = text, fixed = TRUE)),
      "PDF identifier wrapping must preserve the complete DOI/URL characters.")
check(grepl("\\textbf{styled}", text, fixed = TRUE) &&
        grepl("x^2", text, fixed = TRUE) &&
        grepl("\\href{https://example.org/record}", text, fixed = TRUE) &&
        all(vapply(c("1.2", "2.3", "3.5"), grepl, logical(1), x = text, fixed = TRUE)),
      "PDF identifier wrapping changed a styled, mathematical, link or numeric cell.")
check(!grepl("\\setlength\\LTleft{0\\linewidth}", text, fixed = TRUE) &&
        !grepl("\\fontsize{20}", text, fixed = TRUE),
      "PDF headings must retain flexible caption space and fit the book's text size.")
cat("PASS: DOI/URL wrapping preserves characters and existing formats; headings retain flexible width.\n")

labels <- gt::gt(data.frame(n_citation_observed = 300, pooled_year_ratio = 1.11, styled = 1)) |>
  gt::fmt_number(columns = pooled_year_ratio, decimals = 2) |>
  gt::cols_label(styled = gt::md("**Styled** $x^2$"))
text <- as_text(knitr::knit_print(labels))
check(all(vapply(c("\\nolinkurl{n_citation_observed}", "\\nolinkurl{pooled_year_ratio}"),
                 grepl, logical(1), x = text, fixed = TRUE)) &&
        grepl("1.11", text, fixed = TRUE) &&
        grepl("\\textbf{Styled}", text, fixed = TRUE) && grepl("x^2", text, fixed = TRUE),
      "Long column labels must wrap without changing identifiers or numeric values.")
cat("PASS: Long gt column labels retain their exact characters and become breakable.\n")

preamble <- readLines(file.path(repo, "style", "preamble.tex"), warn = FALSE)
wrap_hook <- grep("\\AtBeginDocument{", preamble, fixed = TRUE)
check(length(wrap_hook) == 1L,
      "PDF output wrapping must be installed after all packages have loaded.")
hook_end <- which(trimws(preamble) == "}")
hook_end <- hook_end[hook_end > wrap_hook][1L]
for (environment in c("Highlighting", "verbatim")) {
  line <- which(grepl(paste0("{", environment, "}{Verbatim}"), preamble, fixed = TRUE))
  definition <- preamble[line]
  check(length(definition) == 1L && line > wrap_hook && line < hook_end &&
          grepl("breaklines=true", definition, fixed = TRUE) &&
          grepl("breakanywhere=true", definition, fixed = TRUE),
        paste("PDF preamble must wrap both source and printed output:", environment))
}
cat("PASS: The PDF preamble wraps both highlighted source and plain printed output.\n")

# Exercise the real Pandoc filter, including all TeX escape characters. A table
# code cell must change representation, while its literal content and prose
# code stay intact. HTML serialization must be byte-for-byte unchanged.
check(rmarkdown::pandoc_available(), "Pandoc is required to verify PDF table code.")
pandoc <- file.path(rmarkdown::find_pandoc()$dir, "pandoc")
fixture_file <- tempfile(fileext = ".md")
literal <- r"(x  <- list(a = "two  spaces #%$&_{~}^", b = "\\path"))"
writeLines(c("Outside: `outside_code(x)`.", "", "| Function | Example |",
             "|:---------|:--------|",
             paste0("| `compute_h_index(citations)` | `", literal, "` |")), fixture_file)
filter <- file.path(repo, "scripts", "pdf-table-code.lua")
outputs <- yaml::read_yaml(file.path(repo, "_output.yml"))
filter_arg <- "--lua-filter=scripts/pdf-table-code.lua"
check(filter_arg %in% outputs[["bookdown::pdf_book"]]$pandoc_args &&
        all(vapply(outputs[names(outputs) != "bookdown::pdf_book"], function(output) {
          !filter_arg %in% output$pandoc_args
        }, logical(1))),
      "The table-code filter must be configured only for the PDF book output.")
render_fixture <- function(format, filtered = TRUE) {
  args <- c("--from=markdown", paste0("--to=", format),
            if (filtered) paste0("--lua-filter=", filter), fixture_file)
  output <- system2(pandoc, vapply(args, shQuote, character(1)), stdout = TRUE, stderr = TRUE)
  check(is.null(attr(output, "status")), paste("Pandoc failed for", format))
  as_text(output)
}
latex <- render_fixture("latex")
check(grepl("\\texttt{outside\\_code(x)}", latex, fixed = TRUE) &&
        grepl(paste0("\\EscVerb[breaklines=true,breakanywhere=true,",
                     "breakanywheresymbolpre={},breakanywheresymbolpost={}]{compute\\_h\\_index(citations)}"),
              latex, fixed = TRUE),
      "The PDF filter must wrap table code and leave prose code unchanged.")
escaped <- strsplit(literal, "", fixed = TRUE)[[1L]]
special <- escaped %in% c("\\", "{", "}", "%", "#", "$", "&", "_", "~", "^", " ")
escaped[special] <- paste0("\\", escaped[special])
check(grepl(paste0("{", paste0(escaped, collapse = ""), "}"), latex, fixed = TRUE),
      "The PDF table-code filter changed literal code characters.")
check(identical(render_fixture("html"), render_fixture("html", filtered = FALSE)),
      "The PDF table-code filter must not alter HTML output.")
unlink(fixture_file)
cat("PASS: Pandoc table code preserves literal characters; prose code and HTML are unchanged.\n")

for (format in c("html", "epub3")) {
  knitr::opts_knit$set(rmarkdown.pandoc.to = format)
  # An already-registered wrapper must also be safe before setup is rerun.
  check_html(pdf_printer(table), paste(format, "wrapper fallback"))
  setup_web(format)
  cat("PASS:", format, "restores HTML tables, PNG arguments and the default font.\n")
}

# The normal all-formats build can transition straight from PDF to EPUB.
setup_pdf()
setup_web("epub3")
cat("PASS: Direct PDF-to-EPUB transition restores the original gt printer.\n")
