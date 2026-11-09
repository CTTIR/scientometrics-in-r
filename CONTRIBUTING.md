# Contributing to Scientometrics in R

Thank you for your interest in contributing! This book is an open project and
benefits from community feedback.

## How to contribute

### Report issues

Found a broken code chunk, incorrect citation, or rendering problem? Open an
[issue](https://github.com/CTTIR/scientometrics-in-r/issues) using the
appropriate template.

### Suggest improvements

Use the "Chapter feedback" issue template to suggest content improvements,
missing topics, or clarity edits.

### Submit changes

1. Fork the repository.
2. Create a feature branch from `main` (e.g., `fix/ch10-h-index-typo`).
3. Make your changes. Ensure:
   - `quarto render` succeeds locally.
   - All code chunks execute without error.
   - Any new citations are added to `references.bib` with a valid DOI.
   - Code follows tidyverse style (`styler::style_dir("R/")`).
4. Open a pull request against `main`.

### Branch protection

The `main` branch requires:

- Passing CI checks (all must be green before merge):
  - **Render and Deploy Book** (`render.yml`) — builds HTML via Quarto
  - **R CMD Check** (`check.yml`) — `rcmdcheck --as-cran` on the companion package
  - **Verify Citations** (`citations.yml`) — ensures every `@key` resolves in `references.bib` and DOIs are valid
  - **Lint** (`lint.yml`) — `lintr::lint_dir("R")` and `styler::style_dir("R", dry = "fail")`
- At least one approving review from `@r-heller`
- No force pushes
- No direct pushes — all changes via pull request

### Code style

- R code: tidyverse style, enforced by `lintr` and `styler`.
- Chunk labels: `#| label: <verb>-<noun>` (e.g., `#| label: compute-h-index`).
- Figures: always include `fig-cap` and `fig-alt`.

### Citation policy

Every `@key` in a `.qmd` file must have a matching entry in `references.bib`.
Every entry with a DOI must resolve via Crossref. CI enforces this.

## License

By contributing, you agree that your text contributions are licensed under
CC-BY 4.0 and your code contributions under the MIT License.
