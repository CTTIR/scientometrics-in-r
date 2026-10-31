test_that("current OpenAlex authorships retain stable identities and distinct works", {
  works <- tibble::tibble(id=c("W1","W2","W3"),authorships=list(
    tibble::tibble(id=c("A1","A1","A2"),display_name=c("Alex","Alex","Alex")),
    tibble::tibble(id=c("A1","A2"),display_name=c("A. Example","Alex")),
    tibble::tibble(id="A3",display_name=NA_character_)))
  g <- build_coauth_graph(works)
  expect_setequal(igraph::V(g)$name,c("A1","A2","A3"))
  expect_identical(igraph::V(g)$label,c("Alex","Alex","A3"))
  edge <- igraph::as_data_frame(g,"edges")
  expect_equal(nrow(edge),1L)
  expect_equal(edge$weight,2)
  expect_setequal(c(edge$from,edge$to),c("A1","A2"))
  expect_equal(igraph::degree(g)[['A3']],0)
})

test_that("malformed author schemas fail explicitly and empty inputs stay empty", {
  expect_error(build_coauth_graph(tibble::tibble(id="W1",authorships=list(
    tibble::tibble(display_name="No ID")))),"supported author ID")
  empty <- tibble::tibble(id=character(),authorships=list())
  expect_equal(igraph::vcount(build_coauth_graph(empty)),0)
})
