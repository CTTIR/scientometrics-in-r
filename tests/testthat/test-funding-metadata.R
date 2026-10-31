test_that("missing funder entries cannot count as observed funding metadata", {
  missing <- list(NULL, NA, NA_character_, logical(), list(),
                  data.frame(), data.frame(id = character()),
                  data.frame(id = c(NA_character_, "", " ")))
  for (entry in missing) {
    result <- sci_funder_rows(entry)
    expect_equal(nrow(result), 0L)
    expect_named(result, c("id", "display_name"))
  }
})

test_that("real funder IDs survive with distinct work-funder membership", {
  result <- sci_funder_rows(data.frame(
    id = c("F1", "F1", NA, "F2"),
    display_name = c("First funder", "Alias", "Missing ID", NA)
  ))
  expect_equal(result$id, c("F1", "F2"))
  expect_equal(result$display_name, c("First funder", "F2"))
  expect_equal(sci_funder_rows(data.frame(id = "F3"))$display_name, "F3")
})

test_that("unexpected funder structures fail with a useful diagnosis", {
  expect_error(sci_funder_rows("F1"), "data frame")
  expect_error(sci_funder_rows(list(id = "F1")), "data frame")
  expect_error(sci_funder_rows(data.frame(display_name = "Funder")), "id column")
})
