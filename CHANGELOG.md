# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Removed
- The companion R package `scientometricsInR` (last version 0.2.0) is retired.
  Its functions stay in `R/` as the book's helper scripts, which chapters load
  with `source()`; its 0.2.0 changes (RAKE keyword ranking, offline OpenAlex
  caches, stable author IDs in co-authorship graphs, documented examples) remain.
  `NAMESPACE`, `man/`, `NEWS.md`, the CRAN files, the R CMD check and pkgdown
  workflows and the package site under `/pkg/` are gone.

### Changed
- `DESCRIPTION` is bookdown project metadata (`Type: Book`); its Imports list
  the helper dependencies for `scripts/install-book-deps.R`.
- `fetch_openalex()` reads its cache folder from the `sci.openalex_cache_dir`
  option.
- The helper tests in `tests/testthat/` source `R/` and run in the render workflow.
- The synthetic teaching datasets stay in `data/` (load them with `load()`), with
  their generators in `data-raw/`.

## [0.1.0] - 2026-05-09

### Added
- All 37 chapters across 7 parts, fully written with executable R code
- 5 case studies (CRISPR field review, institutional benchmarking, journal portfolio, gender gap, emerging topics)
- Companion R package structure (`scientometricsInR`) with helper functions
- GitHub Actions workflows (render, check, citations, lint)
- Docker build environment
- "Find Your Method" decision tree (Chapter 0)
- Project palette and theme (`R/sci_palette.R`)
- OpenAlex API caching helper (`R/api_helpers.R`)
- Utility functions: `dedupe_by_doi()`, `compute_h_index()`, `field_normalize()`
- CI citation verification script
- 40+ BibTeX references with resolvable DOIs
- Quarto book configuration with HTML, PDF, and EPUB outputs
- renv lockfile for R package reproducibility
- 5 appendices: R setup guide, OpenAlex SQL primer, glossary, indicator crosswalk, cheatsheets
- Zenodo metadata (`.zenodo.json`) for archival DOI minting
