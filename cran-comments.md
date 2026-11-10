## Submission

This is a new submission.

'scientometricsInR' 0.2.0 is the companion package of the open book
'Scientometrics in R' (<https://cttir.github.io/scientometrics-in-r/>). The book
sources live in the same GitHub repository; `.Rbuildignore` excludes all of
them, so the source package contains only the R package (about 35 kB).

## Test environments

* Local: macOS 27 (aarch64-apple-darwin), R 4.6.1,
  `R CMD check --as-cran` on the built tarball, including the PDF and HTML
  manual (TinyTeX).
* GitHub Actions (`r-lib/actions` v2, `check-r-package`, `--as-cran`
  without the PDF manual): macos-latest (R release), windows-latest
  (R release), ubuntu-latest (R devel, release and oldrel-1).

## R CMD check results

Local: 0 errors | 0 warnings | 1 note

* checking CRAN incoming feasibility ... NOTE
  Maintainer: 'Raban Heller <raban.heller@uni-ulm.de>'
  New submission

  This is a new submission.

## Additional comments

* Network access: `fetch_openalex()` queries the 'OpenAlex' API. The example
  that needs the network runs only in interactive sessions, and the only
  network test is skipped on CRAN and when offline.
* File system: by default `fetch_openalex()` caches in a folder of
  `tempdir()`; users choose a persistent folder explicitly through
  `cache_dir` or the `scientometricsInR.cache_dir` option. Examples and tests
  write only below `tempdir()`.
* Possible spelling flags in DESCRIPTION: 'Kleinberg' is the author of the
  burst detection algorithm; 'normalised' and 'colour' are British spellings
  (`Language: en-GB`).
* All bundled datasets are small synthetic teaching fixtures (under 4 kB each).
