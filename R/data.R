#' Synthetic bibliometric teaching datasets
#'
#' These are simulated teaching fixtures, not records downloaded from OpenAlex
#' or observed CRISPR/journal corpora. Identifiers, DOIs, titles, citations,
#' authors and affiliations are artificial. Do not resolve their example DOIs
#' or use these values as empirical evidence about the named journals or fields.
#'
#' @format Each object is a tibble. `openalex_sample` has 200 rows with simulated
#'   bibliographic and citation fields; `crispr_corpus_mini` has 150 rows with
#'   simulated CRISPR topics and countries; `journal_portfolio_demo` contains
#'   simulated articles from three journal labels. See `names()` and `str()`
#'   for the fields present in each object.
#' @source Local generators in `data-raw/build_openalex_sample.R`,
#'   `data-raw/build_crispr_corpus.R` and `data-raw/build_journal_portfolio.R`,
#'   using random seed 20260509. The bundled files are preserved; no live
#'   provider equivalence or exact regeneration across R versions is claimed.
#' @name teaching_data
NULL

#' @rdname teaching_data
"openalex_sample"

#' @rdname teaching_data
"crispr_corpus_mini"

#' @rdname teaching_data
"journal_portfolio_demo"
