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

options(
  scipen = 999,
  digits = 3,
  knitr.kable.NA = "—",
  # Contact metadata does not replace the API key required for cursor paging.
  openalexR.mailto = "raban.heller@outlook.com"
)

set.seed(42)

if (requireNamespace("ggplot2", quietly = TRUE)) {
  ggplot2::theme_set(
    ggplot2::theme_minimal(base_family = "sans", base_size = 12) +
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

# Register a mermaid chunk engine for bookdown.
# Bookdown does not ship a native mermaid engine like Quarto does; this
# wraps the chunk source in <div class="mermaid">, and the mermaid JS
# included via style/header.html renders it on page load.
knitr::knit_engines$set(mermaid = function(options) {
  if (isFALSE(options$eval)) return("")
  code <- paste(options$code, collapse = "\n")
  paste0(
    '<div class="mermaid">\n',
    code,
    '\n</div>'
  )
})
