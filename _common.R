source("R/api_helpers.R")
if (nzchar(Sys.getenv("OPENALEX_API_KEY"))) {
  options(openalexR.apikey = Sys.getenv("OPENALEX_API_KEY"))
}

knitr::opts_chunk$set(
  echo       = TRUE,
  message    = FALSE,
  warning    = FALSE,
  cache      = TRUE,
  cache.lazy = FALSE,
  fig.align  = "center",
  fig.width  = 7,
  fig.height = 4.5,
  fig.retina = 2,
  dpi        = 300,
  out.width  = "90%",
  comment    = "#>"
)

# Cairo also needs a font containing the actual author-name glyphs. Merely
# preserving a Unicode text mapping can leave visible boxes in the PDF.
if (knitr::is_latex_output()) {
  if (!capabilities("cairo")) stop("PDF figures require R with Cairo support.")
  pdf_fonts <- c("Noto Sans CJK KR", "Noto Sans CJK JP", "Arial Unicode MS")
  installed_fonts <- unique(systemfonts::system_fonts()$family)
  pdf_font <- pdf_fonts[pdf_fonts %in% installed_fonts][1L]
  if (is.na(pdf_font)) {
    stop("PDF output requires Noto Sans CJK (or Arial Unicode MS on macOS).")
  }
  options(sci.pdf_family = pdf_font)
  knitr::opts_chunk$set(dev = "cairo_pdf", dev.args = list(family = pdf_font))

  # gt's natural-width LaTeX columns do not wrap long headings or text. Supply
  # paragraph widths that sum to the text width, retaining longtable page breaks.
  # This print method is registered only in the PDF rendering session.
  local({
    loadNamespace("gt")
    original_gt_print <- getS3method("knit_print", "gt_tbl", envir = asNamespace("knitr"))
    if (is.function(attr(original_gt_print, "sci.original"))) {
      original_gt_print <- attr(original_gt_print, "sci.original")
    }
    pdf_gt_print <- function(x, ..., inline = FALSE) {
      if (!knitr::is_latex_output()) {
        return(original_gt_print(x, ..., inline = inline))
      }
      # Group labels are spanning rows, not selectable body columns. Row labels
      # occupy a separate stub column and must be sized through gt::stub().
      body <- gt::extract_body(x, build_stage = "unfmt_included",
                               incl_stub_cols = FALSE, output = "latex")
      stub <- gt::extract_body(x, build_stage = "unfmt_included",
                               output = "latex")[["::rowname::"]]
      column_weight <- function(text, label) {
        text <- as.character(text)
        lengths <- nchar(text[!is.na(text)], type = "width")
        typical <- if (length(lengths)) as.numeric(stats::quantile(lengths, 0.9)) else 0
        sqrt(max(8, min(60, typical), min(24, nchar(label))))
      }
      weights <- vapply(names(body), function(column) {
        column_weight(body[[column]], column)
      }, numeric(1))
      stub_weight <- if (is.null(stub)) 0 else column_weight(stub, "Row")
      total_weight <- sum(weights) + stub_weight
      widths <- 100 * weights / total_weight
      for (column in names(widths)) {
        x <- gt::cols_width(x, rlang::new_formula(
          rlang::sym(column), gt::pct(unname(widths[[column]]))))
      }
      if (!is.null(stub)) {
        x <- gt::cols_width(x, rlang::new_formula(
          quote(gt::stub(1)), gt::pct(100 * stub_weight / total_weight)))
      }
      # Paragraph columns alone cannot break DOIs, URLs or long identifiers.
      # Transform after gt's formatting, and only plain single-token cells:
      # mathematical expressions, links and styled LaTeX remain intact. xurl
      # supplies break points without adding or deleting identifier characters.
      break_identifier <- function(text) {
        plain <- gsub("\\\\([_&#%])", "\\1", text, perl = TRUE)
        eligible <- !is.na(plain) & grepl(
          "^[[:alnum:]][[:alnum:]/.:_?=&#%+~-]{7,}$", plain)
        text[eligible] <- paste0("\\nolinkurl{", plain[eligible], "}")
        text
      }
      text_columns <- names(body)[vapply(body, is.character, logical(1))]
      if (length(text_columns)) {
        x <- gt::text_transform(x, fn = break_identifier,
                                locations = gt::cells_body(columns = dplyr::all_of(text_columns)))
      }
      if (!is.null(stub)) {
        x <- gt::text_transform(x, fn = break_identifier,
                                locations = gt::cells_stub())
      }
      # Labels use gt's dedicated API, which retains the LaTeX marker class.
      # Mark only changed plain labels as LaTeX; retain styled label objects.
      x <- gt::cols_label_with(x,
        fn = function(label) {
          if (!is.character(label) || is.object(label)) return(label)
          escaped <- gt::escape_latex(label)
          wrapped <- break_identifier(escaped)
          if (identical(wrapped, escaped)) label else gt::latex(wrapped)
        })
      # The column widths already total 100%. Keep longtable's flexible outer
      # glue: gt's explicit 100% table width forces both side skips to zero,
      # producing an overfull caption box even when its text fits the page.
      x <- gt::tab_options(x, table.width = "auto",
                           table.font.size = gt::px(10),
                           heading.title.font.size = gt::px(15),
                           heading.subtitle.font.size = gt::px(12),
                           latex.use_longtable = TRUE)
      knitr::knit_print(gt::as_latex(x), ..., inline = inline)
    }
    attr(pdf_gt_print, "sci.original") <- original_gt_print
    registerS3method("knit_print", "gt_tbl", pdf_gt_print, envir = asNamespace("knitr"))
  })
} else {
  options(sci.pdf_family = NULL)
  knitr::opts_chunk$set(dev = "png", dev.args = list())
  local({
    active <- getS3method("knit_print", "gt_tbl", optional = TRUE, envir = asNamespace("knitr"))
    original <- attr(active, "sci.original")
    if (is.function(original)) {
      registerS3method("knit_print", "gt_tbl", original, envir = asNamespace("knitr"))
    }
  })
}

# Setup has package-loading and registration side effects that cannot be
# recovered by restoring cached objects in a fresh render process.
knitr::opts_hooks$set(cache = function(options) {
  setup <- isTRUE(grepl("(^|[-_])setup($|[-_])", options$label))
  rebuild <- identical(Sys.getenv("SCIENTOMETRICS_REBUILD_CHUNKS"), "1")
  if (setup || rebuild) options$cache <- FALSE
  options
})

options(
  scipen = 999,
  digits = 3,
  knitr.kable.NA = "—",
  # Contact metadata does not replace the API key required for cursor paging.
  openalexR.mailto = "raban.heller@outlook.com",
  # fetch_openalex() caches in tempdir() by default; the book keeps its
  # exact-query caches with the sources.
  scientometricsInR.cache_dir = "_freeze/openalex_cache"
)

set.seed(42)

if (requireNamespace("ggplot2", quietly = TRUE)) {
  ggplot2::theme_set(
    ggplot2::theme_minimal(base_family = getOption("sci.pdf_family", "sans"), base_size = 12) +
      ggplot2::theme(
        plot.title.position   = "plot",
        plot.caption.position = "plot",
        plot.caption          = ggplot2::element_text(hjust = 0, color = "#666"),
        panel.grid.minor      = ggplot2::element_blank()
      )
  )
}

# Copy citation files into docs/citation-files/ on every render so that the
# Citing this Guide page's download links resolve on the deployed site.
local({
  out <- "docs/citation-files"
  if (!dir.exists(out)) dir.create(out, recursive = TRUE, showWarnings = FALSE)
  for (f in c("citation.bib", "citation.ris")) {
    if (file.exists(f)) file.copy(f, file.path(out, basename(f)), overwrite = TRUE)
  }
})

# Render the method navigator with Mermaid only in the web edition.
# A raw HTML fence preserves diagram syntax from Markdown typography changes.
# The adjacent quick-reference table provides navigation in static editions.
knitr::knit_engines$set(mermaid = function(options) {
  if (isFALSE(options$eval)) return("")
  if (!knitr::is_html_output(excludes = c("epub", "epub2", "epub3"))) {
    return(paste0(
      "The decision-tree diagram is available in the web edition. ",
      "Use the quick reference table below to select the relevant method ",
      "and chapter in this edition.\n"
    ))
  }
  code <- paste(options$code, collapse = "\n")
  paste0(
    '\n```{=html}\n<div class="mermaid" tabindex="0" role="region" aria-label="Method decision tree; scroll horizontally on narrow screens">\n',
    code,
    '\n</div>\n```\n'
  )
})
