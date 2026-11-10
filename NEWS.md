# scientometricsInR 0.2.0

## New features

* `rake_keywords()` ranks keyword phrases of one document with Rapid
  Automatic Keyword Extraction (RAKE) degree/frequency scores.
* `fetch_openalex()` gains `offline` (default: `SCIENTOMETRICS_OFFLINE=1`) to
  reuse existing caches without any network request; missing or unreadable
  caches fail explicitly.

## Behaviour changes

* `fetch_openalex()` now caches in the session's temporary directory by
  default instead of `_freeze/openalex_cache` in the working directory. Set
  the `scientometricsInR.cache_dir` option, as the book does, or `cache_dir`
  for a persistent cache.
* `fetch_openalex()` checks its arguments, retries failed requests, never
  caches empty or failed provider responses and replaces cache files
  atomically.
* `build_coauth_graph()` identifies authors by their stable OpenAlex IDs
  (current, legacy and flattened `authorships` layouts), stores display names
  in the `label` and `display_name` vertex attributes and weights edges by the
  number of distinct jointly authored works.
* `theme_sci()` uses the font set in the `sci.pdf_family` option by default.

## Documentation

* All exported functions have runnable examples and documented return values.
* The bundled datasets are documented together in `?teaching_data` as
  synthetic teaching fixtures, not observed OpenAlex records.

## Package infrastructure

* The source package contains only the R package; the book's sources,
  outputs and tooling are excluded from the build.
* The OpenAlex network test is skipped on CRAN and when offline.
* Maintainer e-mail changed to raban.heller@uni-ulm.de.
* GitHub Actions run `R CMD check` on macOS, Windows and Ubuntu (R-devel,
  release and the previous release); the `pkgdown` site build has its own
  workflow.

# scientometricsInR 0.1.0

* Initial version accompanying the first edition of the book, with
  `fetch_openalex()`, `dedupe_by_doi()`, `compute_h_index()`,
  `field_normalize()`, `compute_mncs()`, `build_coauth_graph()`,
  `kleinberg_bursts()`, `palette_sci()`, `theme_sci()` and three synthetic
  teaching datasets.
