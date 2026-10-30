# Synthetic teaching fixture: not downloaded provider records or empirical evidence.
# Build openalex_sample dataset
# A small sample of OpenAlex works for use in book examples.
# Run this script from the project root to regenerate data/openalex_sample.rda

library(tibble)
set.seed(20260509)

n <- 200
years <- sample(2015:2024, n, replace = TRUE)

openalex_sample <- tibble(
  id = paste0("W", seq_len(n)),
  doi = paste0("10.1234/example.", seq_len(n)),
  title = paste("Sample paper on scientometrics topic", seq_len(n)),
  publication_year = years,
  type = sample(c("article", "review", "editorial"), n,
                replace = TRUE, prob = c(0.8, 0.15, 0.05)),
  cited_by_count = rnbinom(n, mu = 12, size = 1.5),
  is_oa = sample(c(TRUE, FALSE), n, replace = TRUE, prob = c(0.45, 0.55)),
  language = sample(c("en", "de", "fr", "zh", "es"), n,
                    replace = TRUE, prob = c(0.75, 0.05, 0.05, 0.10, 0.05)),
  source_display_name = sample(
    c("Scientometrics", "Journal of Informetrics",
      "Research Evaluation", "Quantitative Science Studies",
      "Journal of the Association for Information Science and Technology"),
    n, replace = TRUE
  ),
  author_count = sample(1:8, n, replace = TRUE, prob = c(0.1, 0.25, 0.25, 0.2, 0.1, 0.05, 0.03, 0.02)),
  field = sample(
    c("bibliometrics", "network science", "research evaluation",
      "text mining", "open science"),
    n, replace = TRUE
  ),
  referenced_works_count = rpois(n, lambda = 30)
)

usethis::use_data(openalex_sample, overwrite = TRUE)
cat("Created data/openalex_sample.rda\n")
