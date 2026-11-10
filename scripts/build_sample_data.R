# build_sample_data.R
# Rebuilds the bundled sample datasets from OpenAlex.
# Run manually; outputs go to data/ as .rda files.

library(openalexR)
library(dplyr)

# Small sample: 200 works from scientometrics-adjacent journals
openalex_sample <- oa_fetch(
  entity = "works",
  primary_location.source.id = "S148561398",
  from_publication_date = "2020-01-01",
  to_publication_date = "2023-12-31",
  options = list(sample = 200, seed = 42)
)

save(openalex_sample, file = "data/openalex_sample.rda", compress = "xz")

cat("Sample datasets built and saved to data/\n")
