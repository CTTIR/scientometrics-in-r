test_that("palette_sci returns correct number of colours", {
  cols <- palette_sci(4)
  expect_length(cols, 4)
  expect_true(all(grepl("^#[0-9A-Fa-f]{6}", cols)))
})

test_that("theme_sci returns a ggplot theme", {
  thm <- theme_sci()
  expect_s3_class(thm, "theme")
})

test_that("PDF font selection reaches plotted text and permits an explicit override", {
  previous <- options(sci.pdf_family = "Arial Unicode MS")
  on.exit(options(previous), add = TRUE)
  expect_identical(theme_sci()$text$family, "Arial Unicode MS")
  expect_identical(theme_sci(base_family = "serif")$text$family, "serif")
  options(sci.pdf_family = NULL)
  expect_identical(theme_sci()$text$family, "")
})
