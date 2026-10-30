test_that("RAKE scores phrases by hand-computed degree/frequency", {
  result <- rake_keywords("red apple and red apple pie. apple", "and", 3)
  expect_equal(result$keyword, c("red apple pie", "red apple", "apple"))
  expect_equal(result$score, c(7.5, 4.5, 2))
  expect_equal(result$frequency, c(1L, 1L, 1L))
})

test_that("delimiters, repetitions and top-n preserve phrase semantics", {
  result <- rake_keywords("Green tea, green tea and blue sky! 42 red", "and", 10)
  expect_setequal(result$keyword, c("green tea", "blue sky", "red"))
  expect_equal(result$frequency[result$keyword == "green tea"], 2L)
  expect_equal(result$score[result$keyword == "green tea"], 4)
  expect_equal(rake_keywords("and the", c("and", "the"))$keyword, character())
  expect_equal(nrow(rake_keywords("alpha beta. gamma", character(), 1)), 1L)
  expect_equal(rake_keywords("", character())$score, numeric())
})

test_that("RAKE rejects invalid documents and limits", {
  expect_error(rake_keywords(NA_character_, "and"), "text")
  expect_error(rake_keywords(c("a","b"), "and"), "text")
  expect_error(rake_keywords("a", NA_character_), "stopwords")
  for (n in list(0, 1.5, NA_real_, Inf)) expect_error(rake_keywords("a", "and", n), "n_keywords")
})
