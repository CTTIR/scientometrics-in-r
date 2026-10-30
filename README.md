<p align="center"><a href="https://r-heller.github.io/scientometrics-in-r/"><img src="images/cover.png" alt="Scientometrics in R cover" width="280"></a></p>

# Scientometrics in R

*Bibliometrics, Network Science, and Research Evaluation*

A free, open-source book by **Raban Heller**.

## Read it online

📖 **<https://r-heller.github.io/scientometrics-in-r/>**

## Download

- 📄 [Whole book (PDF)](https://r-heller.github.io/scientometrics-in-r/scientometrics-in-r.pdf)
- 📚 [EPUB](https://r-heller.github.io/scientometrics-in-r/scientometrics-in-r.epub)
- 📑 Per-chapter PDFs: every chapter page has a download button at the top right.

## What this book covers

The book is a hands-on guide to scientometrics in R. It covers the
full workflow from data acquisition (OpenAlex, Crossref, PubMed)
through core bibliometric indicators, network analysis, text mining,
and production reporting. Examples use free, open data sources. Live API
results change, some operations require credentials, and exact reproduction
requires the same cached corpus and software environment. No Web of Science or
Scopus subscription is required. The bundled companion datasets are **synthetic
teaching fixtures**, not measured OpenAlex records or empirical evidence.

It is written for researchers, librarians, research administrators,
and data scientists who already know R at a tidyverse level and want
to add bibliometric methods to their toolkit. The book is unusually
explicit about *limitations and responsible use*: every quantitative
chapter ends with a callout grounded in the Leiden Manifesto and DORA.

What it does *not* cover: proprietary platforms (InCites, SciVal),
manual screening workflows for systematic reviews, and qualitative
sociology of science.

## Table of contents

The book has eight parts plus appendices:

- **Part I — Foundations** (Ch. 1–4): what scientometrics is, its
  theoretical roots, ethics, and data sources compared.
- **Part II — Data Acquisition** (Ch. 5–8): APIs, native exports,
  reproducible corpora, full-text.
- **Part III — Core Bibliometrics** (Ch. 9–14): descriptive metrics,
  productivity & impact, journal metrics, author/institution/temporal
  analysis.
- **Part IV — Network & Mapping** (Ch. 15–20): co-authorship,
  co-citation, co-word, community detection, science mapping,
  interoperability with Gephi/VOSviewer.
- **Part V — Text & Topic** (Ch. 21–25): text mining, topic models,
  keyword extraction, embeddings, emerging-topic detection.
- **Part VI — Advanced Topics** (Ch. 26–33): altmetrics, open-science
  indicators, gender, retractions, funding, patents, causal inference,
  reproducibility metadata.
- **Part VII — Production & Reporting** (Ch. 34–37): targets
  pipelines, dashboards, parameterised reports, Shiny apps.
- **Part VIII — Case Studies** (5 worked examples) and **5 appendices**
  (R setup, OpenAlex snapshot SQL, glossary, indicator crosswalk,
  cheatsheets, exercise solutions).

## How to cite

> Heller, R. (2026). *Scientometrics in R: Bibliometrics, Network
> Science, and Research Evaluation*.
> <https://r-heller.github.io/scientometrics-in-r/>

```bibtex
@book{heller2026scientometrics,
  author    = {Heller, Raban},
  title     = {Scientometrics in {R}: Bibliometrics, Network Science, and Research Evaluation},
  year      = {2026},
  url       = {https://r-heller.github.io/scientometrics-in-r/},
  publisher = {Self-published}
}
```

## Build status and API access

The companion R package passes local build and check. The full book is not yet
release-qualified: the 30 October 2026 HTML run reached Chapter 12 and stopped
when OpenAlex required authentication for cursor paging. Later chapters and all
publication formats remain to be validated. See `MAINTENANCE.md`.

OpenAlex's [authentication documentation](https://help.openalex.org/api/authentication/)
requires a free, activated key for paging beyond the first page. Keep it outside
Git. This book accepts `OPENALEX_API_KEY`; existing `openalexR.apikey` environment
or R-option configuration also works. Neither the key nor a live corpus should
be placed in a commit. Supplying a key enables requests against its account budget.

Chapter code uses `fetch_openalex()` with exact-argument RDS caches in
`_freeze/openalex_cache/`. Set `SCIENTOMETRICS_OFFLINE=1` to require existing
OpenAlex caches, including stale ones; a missing/unreadable cache fails explicitly.
This mode does not make Crossref, PubMed, or other providers offline.
Do not reuse old knitr caches when validating changed analysis code.

## Reproducibility

Built with [bookdown](https://bookdown.org/), R, and `renv`. To
rebuild locally:

```bash
git clone https://github.com/r-heller/scientometrics-in-r.git
cd scientometrics-in-r
R -e 'renv::restore()'
R -e 'bookdown::render_book("index.Rmd", output_format = "all")'
```

A Docker image (`Dockerfile`) is provided for fully reproducible
builds.

## Use of LLM tools

Portions of this book were prepared with assistance from large language model tooling for
narrowly defined, non-authorial tasks: copyediting, prose smoothing, Markdown/LaTeX formatting,
scaffolding of boilerplate files (CI configs, build scripts), code refactoring. The tools used were [Chat AI](https://kisski.gwdg.de/leistungen/2-02-llm-service/),
the LLM service of KISSKI (GWDG), and a self-hosted **Mistral Small (24B, Apache-2.0)** run locally via
[Ollama](https://ollama.com/) and the `ollamar` R package — local inference only, with no data sent to
third parties for the self-hosted model.

All scientific claims, methodological choices, analyses, interpretations, and conclusions are the
author's own. No LLM-generated text was incorporated without review and revision, and every reference
was verified against its DOI, arXiv ID, or ISBN.

## License

The prose of this book is licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/); all code (scripts, chunks, examples) is licensed under the [MIT License](LICENSE-CODE).

## Contributing

Issues and PRs welcome — see [CONTRIBUTING.md](CONTRIBUTING.md).
