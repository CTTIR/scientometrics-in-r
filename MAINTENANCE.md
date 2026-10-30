# Maintenance review — 30 October 2026

## Purpose and priorities

A scientometrics teaching book and small companion package. Essential repairs:
correct mislabeled analytical methods, preserve data provenance, make provider
reuse reproducible, and produce a clean companion archive. Full-book readiness
also requires an authenticated, executed build and verified publication formats.

## Confirmed findings and repairs

- High: Chapter 23 called unigram frequency ranking RAKE. `R/rake_keywords.R`
  now implements candidate phrases separated by stopwords/punctuation and scores
  word degree/frequency, with a hand-calculated regression. This is basic RAKE;
  it does not imply validated keyword accuracy for a particular corpus. Removed
  unsupported universal keyword-accuracy percentages; evaluation must report
  measured results and its matching protocol.
  Method source: Rose et al., DOI 10.1002/9780470689646.ch1.
- High: the companion datasets are randomly generated teaching fixtures but had
  no dataset documentation. Added documentation and explicit synthetic labels,
  keeping every data file unchanged and preserving generator seed 20260509.
- Medium: OpenAlex caching lacked an explicit offline contract. Cache filenames
  now hash exact arguments, writes replace atomically, and offline requests use
  existing caches or fail without calling the provider. All chapter R calls use
  the wrapper. Other providers still need their own network access.
- Medium: book exports overwrote a tracked Parquet fixture. Export chunks now
  write to `_freeze/exports`; the original fixture was restored unchanged and
  the audit-generated live corpus retained separately.
- Medium: Docker launched Quarto in a bookdown project. Its command now renders
  bookdown. The image itself has not been built locally.
- Packaging: preserve separate prose/code licenses, use the standard MIT LICENCE
  stub for the R package, document exported helpers/data, and exclude book assets,
  generated files and linked-worktree metadata from the package archive.

## Evidence and limitations

R 4.6.1, macOS arm64. Full companion tests passed (9.69 s); offline/RAKE regressions
passed (2.07 s). Installed-package first use passed (0.55 s): documented
synthetic dataset sizes, hand-computed RAKE values and offline cache hit/miss. Final source build (0.50 s) and full `R CMD check --no-manual`
(23.40 s) passed, Status OK. The initial two warnings and one note (license, data
help, placeholder file) were repaired rather than suppressed.

Actual book builds exposed missing dependencies, which were installed in the
audit library. The subsequent HTML build executed through Chapter 11 and stopped
at Chapter 12: OpenAlex returned HTTP 401, requiring an API key for cursor paging.
The full book is NOT verified. Upstream documentation confirms that requirement:
https://help.openalex.org/api/authentication/ . README describes credential setup
without embedding a key; CI accepts OPENALEX_API_KEY from an encrypted secret.
Local package versions were current available versions, not a qualified restore
of every historical lockfile pin. Later chapters, live providers, Python model
backends, Docker, PDF/EPUB, remote CI and deployment remain unverified.

## First use and remaining roadmap

For the package, with R >= 4.1: install remotes, run
`remotes::install_deps(dependencies = TRUE)` and
`remotes::install_local(".", dependencies = FALSE)` from this checkout.
Use `library(scientometricsInR)` and `?rake_keywords`; dataset help explicitly
identifies synthetic fixtures. For the book, follow README's dependency restore,
configure an activated key locally, and render with bookdown. A missing cache in
SCIENTOMETRICS_OFFLINE mode is an error, not a synthetic substitute.

Next: complete an authenticated HTML build, repair any later execution failures,
then validate PDF/EPUB and links before release. Longer-term: freeze complete
versioned corpora with source dates/licenses and validate extraction quality on
an explicitly defined annotated corpus. No push, submission or deployment occurred.
