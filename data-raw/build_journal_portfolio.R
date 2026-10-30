# Synthetic teaching fixture: not downloaded provider records or empirical evidence.
# Build journal_portfolio_demo dataset
# A small journal portfolio dataset for case study 3 examples.
# Run this script from the project root to regenerate data/journal_portfolio_demo.rda

library(tibble)
set.seed(20260509)

journals <- c("Scientometrics", "Journal of Informetrics",
              "Quantitative Science Studies")

rows <- lapply(journals, function(j) {
  n <- sample(60:100, 1)
  years <- sample(2015:2024, n, replace = TRUE)
  tibble(
    id = paste0("W", sample(20000:99999, n)),
    doi = paste0("10.1234/jp.", sample(10000:99999, n)),
    title = paste(j, "article", seq_len(n)),
    publication_year = years,
    cited_by_count = rnbinom(n, mu = 10, size = 1.5),
    is_oa = sample(c(TRUE, FALSE), n, replace = TRUE),
    source_display_name = j,
    author_count = sample(1:6, n, replace = TRUE),
    type = sample(c("article", "review"), n, replace = TRUE,
                  prob = c(0.85, 0.15)),
    referenced_works_count = rpois(n, lambda = 35),
    self_citation_count = rpois(n, lambda = 2)
  )
})

journal_portfolio_demo <- dplyr::bind_rows(rows)

usethis::use_data(journal_portfolio_demo, overwrite = TRUE)
cat("Created data/journal_portfolio_demo.rda\n")
