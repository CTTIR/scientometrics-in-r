test_that("a common year reference allows actual between-sample differences", {
  a <- data.frame(id=c("a","b"), publication_date=c("2020-01-01","2020-02-01"), cited_by_count=c(0,20))
  b <- data.frame(id=c("c","d"), publication_date=c("2020-03-01","2020-04-01"), cited_by_count=c(10,30))
  reference <- sci_pooled_year_reference(list(a,b))
  expect_equal(reference$pooled_year_mean, 15)
  expect_equal(sci_sample_citation_summary(a,reference)$pooled_year_ratio, 2/3)
  expect_equal(sci_sample_citation_summary(b,reference)$pooled_year_ratio, 4/3)
  # The former institution-specific normalization would give one for both.
  expect_equal(mean(a$cited_by_count/mean(a$cited_by_count)), 1)
  expect_equal(mean(b$cited_by_count/mean(b$cited_by_count)), 1)
})

test_that("shared works enter the reference once and inconsistent snapshots fail", {
  a <- data.frame(id=c("a","shared"),publication_date=rep("2020-01-01",2),cited_by_count=c(0,20))
  b <- data.frame(id=c("shared","b"),publication_date=rep("2020-01-01",2),cited_by_count=c(20,80))
  expect_equal(sci_pooled_year_reference(list(a,b))$pooled_year_mean,100/3)
  b$cited_by_count[1] <- 21
  expect_error(sci_pooled_year_reference(list(a,b)),"inconsistent snapshots")
  expect_error(sci_pooled_year_reference(list(a,a[c(1,1),])),"unique")
})

test_that("zero reference years and missing counts have explicit denominators", {
  a <- data.frame(id=c("a","b","c"),publication_date=c("2020-01-01","2021-01-01",NA),cited_by_count=c(0,10,NA_real_))
  reference <- sci_pooled_year_reference(list(a))
  summary <- sci_sample_citation_summary(a,reference)
  expect_equal(summary$n_sampled,3)
  expect_equal(summary$n_citation_observed,2)
  expect_equal(summary$n_ratio_observed,1)
  expect_equal(summary$pooled_year_ratio,1)
  expect_equal(summary$mean_cites,5)
  expect_true(is.na(sci_sample_citation_summary(a[1,,drop=FALSE],reference)$pooled_year_ratio))
})

test_that("fractional credit counts distinct institutions and reports coverage", {
  authors <- function(ids) data.frame(affiliations=I(list(data.frame(id=ids))))
  works <- data.frame(id=c("a","b"),authorships=I(list(
    authors(c("https://openalex.org/I1","https://openalex.org/I1","https://openalex.org/I2")),
    authors("I1"))))
  counts <- sci_institution_sample_counts(works,"I1")
  expect_equal(counts$full_count,2)
  expect_equal(counts$affiliation_covered,2)
  expect_equal(counts$frac_count,1.5)
  works$authorships[[2]] <- authors(character())
  missing <- sci_institution_sample_counts(works,"I1")
  expect_equal(missing$affiliation_covered,1)
  expect_true(is.na(missing$frac_count))
  works$authorships[[2]] <- authors("I2")
  expect_true(is.na(sci_institution_sample_counts(works,"I1")$frac_count))
})

test_that("partially missing affiliations do not become full institutional credit", {
  incomplete <- list(NULL, data.frame(id=character()),
                     data.frame(id=NA_character_),
                     data.frame(id=c("I2", NA_character_)))
  for (entry in incomplete) {
    authors <- data.frame(affiliations=I(list(data.frame(id="I1"), entry)))
    works <- data.frame(id="partial", authorships=I(list(authors)))
    counts <- sci_institution_sample_counts(works,"I1")
    expect_equal(counts$full_count,1)
    expect_equal(counts$affiliation_covered,0)
    expect_true(is.na(counts$frac_count))
  }
  authors <- data.frame(affiliations=I(list(data.frame(id="I1"), data.frame(id="I2"))))
  works <- data.frame(id="complete", authorships=I(list(authors)))
  expect_equal(sci_institution_sample_counts(works,"I1")$frac_count,0.5)
})
