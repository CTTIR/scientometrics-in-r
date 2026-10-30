# Synthetic teaching fixture: not downloaded provider records or empirical evidence.
# Build crispr_corpus_mini dataset
# A small CRISPR-related corpus for case study examples.
# Run this script from the project root to regenerate data/crispr_corpus_mini.rda

library(tibble)
set.seed(20260509)

n <- 150
years <- sample(2010:2024, n, replace = TRUE,
                prob = c(0.01, 0.01, 0.02, 0.03, 0.05, 0.06, 0.08,
                         0.10, 0.12, 0.12, 0.10, 0.10, 0.08, 0.07, 0.05))

topics <- c("CRISPR-Cas9", "gene editing", "guide RNA", "base editing",
            "prime editing", "epigenome editing", "delivery", "off-target",
            "diagnostics", "agriculture")

crispr_corpus_mini <- tibble(
  id = paste0("W", 10000 + seq_len(n)),
  doi = paste0("10.1234/crispr.", seq_len(n)),
  title = paste("CRISPR research paper", seq_len(n)),
  publication_year = years,
  cited_by_count = rnbinom(n, mu = 25, size = 1.2),
  is_oa = sample(c(TRUE, FALSE), n, replace = TRUE, prob = c(0.55, 0.45)),
  source_display_name = sample(
    c("Nature", "Science", "Cell", "Nature Biotechnology",
      "Nature Methods", "Molecular Cell", "Nucleic Acids Research",
      "CRISPR Journal", "Genome Biology", "ACS Nano"),
    n, replace = TRUE
  ),
  author_count = sample(2:12, n, replace = TRUE),
  primary_topic = sample(topics, n, replace = TRUE),
  referenced_works_count = rpois(n, lambda = 40),
  institution_country = sample(
    c("US", "CN", "DE", "UK", "JP", "KR", "FR", "CA", "AU", "NL"),
    n, replace = TRUE, prob = c(0.30, 0.25, 0.08, 0.08, 0.07,
                                0.05, 0.05, 0.04, 0.04, 0.04)
  )
)

usethis::use_data(crispr_corpus_mini, overwrite = TRUE)
cat("Created data/crispr_corpus_mini.rda\n")
