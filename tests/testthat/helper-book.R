# These tests check the book's helper functions in R/. Chapters load them with
# source(), so the tests do the same. Run from the repository root:
#   Rscript --vanilla -e 'testthat::test_dir("tests/testthat")'
book_helpers <- environment()
for (helper in list.files(test_path("..", "..", "R"), pattern = "[.]R$", full.names = TRUE)) {
  source(helper, local = book_helpers)
}

# Temporarily replace helper functions within one test, as
# testthat::local_mocked_bindings() does for functions in a package.
local_helper_bindings <- function(..., .frame = parent.frame()) {
  rlang::local_bindings(..., .env = book_helpers, .frame = .frame)
}
