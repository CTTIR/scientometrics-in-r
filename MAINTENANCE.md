# Maintenance review — 30 October–2 November 2026

## Purpose and acceptance criteria

A scientometrics teaching book and companion R package for researchers, librarians
and research administrators. This local milestone requires truthful analytical
labels, preserved author/data provenance, explicit provider failures, a usable
reading site, inspectable publication files and an installable companion archive.
Hosted CI, publication and scientific/editorial acceptance are separate gates.

The roadmap prioritised (1) incorrect results and claims, (2) dependable provider
and package behaviour, (3) executable onboarding and readable publication formats.
A frozen, licensed corpus and a fully pinned toolchain remain a later milestone;
adding more methods was outside this repair pass.

## Confirmed findings and completed repairs

- **High — incorrect scientific labels.** Chapters 10/11/13 and related solutions
  called within-sample ratios or cumulative citations world-normalized MNCS,
  JIF/SNIP, or institutional productivity. They now state the actual samples,
  denominators and reference construction; undefined values remain missing.
  Chapter 14's related exercise distinguishes publication cohorts from citation
  receipt windows. Chapters 31/32/33 now distinguish ordinary scholarly citations,
  descriptive cohort interactions and access metadata from patent evidence,
  causal effects and reproducibility measures. These distinctions prevent readers
  from treating available metadata as evidence for an unmeasured outcome.
- **High — wrong entities.** Chapter 13 and Case Study 2 included invalid institution
  IDs and a University of Zurich ID labelled ETH Zurich. Chapter 11 included three
  invalid journal IDs and Current Forestry Reports labelled Quantitative Science
  Studies. Current identities were checked against OpenAlex records, corrected,
  and exercised. Empty/failed comparisons stop instead of silently losing entities.
- **High — unsupported demographic inference.** Chapter 28 and Case Study 4 assigned
  genders to real authors using short unvalidated name lists. Their mechanics are
  now illustrated with explicitly synthetic records and arbitrary categories,
  retaining unmatched records and making no empirical gender-gap claim.
- **High — mislabeled keyword method.** The previous milestone replaced unigram
  frequency ranking with basic RAKE (`R/rake_keywords.R`), including a hand-computed
  regression, and removed unsupported universal accuracy percentages. Extraction
  quality still needs evaluation on a defined annotated corpus.
- **High — identity and missingness.** `R/utils.R` preserves stable author IDs in
  graph vertex `name`, with human-readable `label`/`display_name`; homonyms stay
  separate and repeated work/author records do not inflate edges. Institutional
  fractional credit requires usable affiliations for every listed author.
  `R/funding_helpers.R` rejects missing funder IDs rather than counting NA as funding.
  Chapters 17/CS03 distinguish OpenAlex topics from their parent taxonomy levels.
- **Medium — provider reliability and preservation.** `R/api_helpers.R` uses exact
  argument caches, atomic replacement and explicit offline hit/miss behaviour.
  Exhausted HTTP warnings from openalexR now fail rather than becoming apparent
  empty successes. Tracked teaching fixtures are unchanged and documented as
  synthetic. Generated live exports go to `_freeze/exports`.
- **Medium — execution and distribution.** Added a shared 53-package installer for
  readers and CI, including the missing `reshape2` dependency. Historical renv and
  Docker paths are explicitly unqualified; Appendix A now describes bookdown/docs.
  PDF text and Cairo figures select a Unicode-capable font to preserve non-Latin
  author labels; tables and code wrap within the page. PDF printing settings are
  restored before subsequent HTML/EPUB renders in the same R session. The method navigator
  is readable, keyboard-scrollable and unnumbered; chapter numbering is consistent.
  Available-file inventories replace unconditional download links. Optional chapter
  PDF generation reports failure through its exit status. The download list is
  also available in mobile navigation; it no longer depends on a desktop-only
  sidebar.
- **Medium — EPUB packaging.** The rendered EPUB contained malformed XHTML,
  missing citation/licence files and cross-chapter links that pointed into the
  wrong chapter. The explicit packaging step repairs only deterministic targets,
  bundles the source assets and validates the result before replacing the input.
  Ambiguous or missing targets fail without replacing the original ebook. CI and
  first-use instructions include this step before publishing a download inventory.
- **Medium — validation before publication.** Manual book and package CI runs
  previously also deployed their output. Manual runs now default to build-only;
  publication requires selecting the explicit `deploy` input. Manual book runs
  retain a downloadable review artifact. Existing main-push and scheduled
  deployment behaviour is unchanged. Hosted execution remains unverified.
- **Packaging.** Preserve the separate prose/code licences and original authorship.
  Exclude caches, live exports, figures, temporary HTML and TeX logs from the
  companion source archive, including when a book render is in progress.

## Observed verification

All seven R files pass lintr with zero findings and styler without changes. The
style repairs preserve parsed expressions apart from two explicit internal-helper
renames and single-statement braces; neither check was relaxed. The final HTML,
PDF and EPUB were rebuilt on 31 October from source commit `b050100` in separate
worktrees and fresh R processes. Every analysis chunk was re-executed with copies
of the verified provider caches. All three builds succeeded, and every tracked
source file still matched its committed Git blob. Final artifact review and local
distribution assembly completed on 2 November. The subsequent HTML-only mobile
download fix was synchronized from `style/after-body.html` into all 59 reading
pages. Reversing that exact fragment restores every pre-update byte; analysis,
search content, PDF and EPUB were unchanged. The preserved full-build outputs
and fragment hashes document this final UI update separately.

R 4.6.1 on macOS arm64. Authentication and a cursor request returned HTTP 200;
no credential was placed in source. An initial render stopped at Chapter 22 on
missing `reshape2`; this was installed in the audit library and added to the
shared dependency inventory. Earlier failures are retained in the audit logs.

- The final companion source archive passed `R CMD check --no-manual --no-vignettes`, Status OK, with **126 passing assertions**, no warnings or
  skips. It contains 43 members (29,468 bytes), and every source-backed member
  matches this checkout. No generated or live-data files are included. A
  separate build during active PDF compilation also excluded all TeX auxiliary
  files. The checked archive SHA256 is
  `bee3e3b308e148bb48732272eaa7194a55daa0d9a4dbbd72b844769c8017e33f`.
- Fresh installation and first use of that final archive passed: bundled datasets,
  independently calculated RAKE scores and offline cache hit/miss behaviour.
- All 53 required package namespaces load. All 67 configured Rmd files parse.
  Independent checks cover author identity, partial affiliations, missing funding,
  normalization, synthetic categories, descriptive interactions, actual cached
  institution/journal/topic workflows and repaired solution snippets.
- Download inventory and browser visibility cases pass. Desktop/mobile search,
  navigation, corrected content and the readable method diagram were observed.
  Final desktop and mobile download responses match the qualified file hashes;
  mobile EPUB click/save and PDF navigation passed. Missing inventories show no
  download links, and there are no duplicate download IDs or advertised missing
  chapter PDFs.
  The final site has 59 HTML pages and 8,013 checked local references, with no
  broken targets or visible unresolved references. Search contains 866 sections
  across 58 content pages. `scripts/verify-render-formats.R` also passes PDF,
  repeated-PDF, HTML and EPUB transitions without leaking table/device settings.
- EPUB packaging passes 35 regression checks and a byte-identical repeat run.
  The final ebook has 161 archive members, 65 XHTML documents and 8,620 checked
  internal references. Official EPUBCheck 5.4.0 with `--failonwarnings` reports
  zero findings. Independent comparison preserves all 92 other original assets
  byte-for-byte and all 62 original XHTML text sequences without substitutions. Representative tables and citation/licence fallback
  pages were visually checked, including a 390-pixel viewport. These are XHTML
  rendering checks, not acceptance in every dedicated ebook reader.
- The PDF typography specimens and 11 format regression groups pass, including
  exact DOI/header/code content, repeated spaces, Unicode names, grouped tables,
  hidden columns and plain-output wrapping. The final **609-page PDF** has no
  missing glyphs, undefined references, replacement characters or extracted words
  outside the page. Eleven representative final pages were independently viewed,
  including repaired tables, qualified scientific claims, Unicode labels and the
  `b050100` colophon. This is representative inspection, not page-by-page proofing.
- Manual publication controls passed YAML parsing and deployment/artifact event
  checks. Manual workflows default to validation without publication; hosted
  execution remains unobserved.

The final local distribution contains the fresh HTML and these qualified files:

| Artifact | Bytes | SHA256 |
|---|---:|---|
| `docs/scientometrics-in-r.pdf` | 6,041,651 | `894f6649a87576a5cf61c42f6a9d4c5ff36eea45cbc532284e2103540262c2b3` |
| `docs/scientometrics-in-r.epub` | 33,044,709 | `8ff30dcdc238d61340b73b23ae0a74111e46b7debe23fb2b6201c8f28183e913` |

The previous distribution and raw EPUB were preserved in the audit directory.
The source fixtures, reference bibliography and executable generator contents are
unchanged; three generator files retain only their previously documented
synthetic-provenance comment. Final download checks passed and all four owned
preview servers were stopped.

The exact credential scan checked 5,136 files and 1,291 compressed streams,
including current source, caches and distribution files, with zero matches and
zero current-candidate extraction errors. Eleven historical incomplete audit
PDFs could not be text-extracted; their raw bytes were scanned and the exceptions
remain listed. The credential process was then closed. The later mobile-only
fragment update used no credentials, and its exact-byte preservation check
confirms the other artifact content remained unchanged.

Detailed command receipts, source hashes, failures and independent review notes
are retained under the workspace's
`.repository-audit/2026-10-30-rheller-refinement/scientometrics-in-r/` directory.
No remote CI result, deployment or submission is represented as locally verified.

## First use and release boundary

Follow README's installer and render commands from this candidate checkout.
Serve existing output with `python3 -m http.server 8000 --directory docs` and visit
`http://localhost:8000`. Configure an activated OpenAlex key outside Git for
uncached requests. `SCIENTOMETRICS_REBUILD_CHUNKS=1` re-executes analysis while
retaining exact-query provider caches. `SCIENTOMETRICS_OFFLINE=1` covers OpenAlex
only and cannot replace missing caches. Graph display names are in `label` or
`display_name`; `name` now intentionally holds stable author IDs.

The full book's historical lockfile/Docker restore, installation of all book
packages into an otherwise empty machine, optional Python/SQL/OCR backends and
live Shiny/deployment exercises remain unqualified. Exercise-solution chunks are
intentionally unevaluated by the book renderer; repaired snippets were checked
independently, but not every solution was executed. Minor upstream deprecation
messages, front-matter subsection numbering and repeated callout headings are
deferred. The PDF retains 152 minor overfull-box warnings (contents, running heads
and body/table margins; maximum 29.03 pt); representative affected content remains
readable. This pass does not
constitute independent scientific or editorial acceptance of the entire text.

Next release action: review the candidate and rendered books. After authorization,
push the review branch, configure the GitHub `OPENALEX_API_KEY` secret, and run
the manual book/package workflows on that revision with `deploy` unchecked. Review their results and the book
artifact before an authorized publication. The existing main-push and scheduled
workflows still deploy automatically, so a push to main is a publication step.
No push, merge, deployment or submission occurred.
