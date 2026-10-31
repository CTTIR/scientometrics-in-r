# Run from the repository root: Rscript scripts/verify-embedding-preprocessing.R
# Exercise the actual chapter functions without fetching data or fitting a model.
chapter <- readLines("chapters/24-embeddings-scientometrics.Rmd", warn = FALSE)

chunk_code <- function(label) {
  start <- which(chapter == paste0("#| label: ", label))
  stopifnot(length(start) == 1L)
  finish <- which(seq_along(chapter) > start & chapter == "```")[1L]
  parse(text = chapter[seq.int(start + 1L, finish - 1L)])
}

assignment <- function(expressions, name) {
  found <- Filter(function(expr) {
    is.call(expr) && identical(expr[[1L]], as.name("<-")) &&
      identical(expr[[2L]], as.name(name))
  }, as.list(expressions))
  stopifnot(length(found) == 1L)
  found[[1L]]
}

env <- new.env(parent = asNamespace("stringr"))
env$text_df <- data.frame(text = c("Citation AI research", "citation ai research"))
eval(assignment(chunk_code("24-train-word2vec"), "clean_text"), env)
stopifnot(identical(env$clean_text, rep("citation ai research", 2L)))
eval(assignment(chunk_code("24-document-embeddings"), "doc_embed"), env)

# Known vectors let us check the scientific quantity: the average of every
# matched token, including capitalised terms, acronyms, and repeated words.
vectors <- rbind(citation = c(1, 0), ai = c(0, 1), research = c(1, 1))
stopifnot(
  isTRUE(all.equal(env$doc_embed("Citation AI research", vectors), c(2/3, 2/3))),
  isTRUE(all.equal(env$doc_embed("Citation,\nAI! research", vectors), c(2/3, 2/3))),
  isTRUE(all.equal(env$doc_embed("Citation citation AI", vectors), c(2/3, 1/3))),
  isTRUE(all.equal(env$doc_embed("Unknown Citation", vectors), c(1, 0))),
  identical(env$doc_embed("unknown", vectors), rep(NA_real_, 2L))
)
cat("Chapter 24 embedding preprocessing: 6 checks passed; no network or model fit.\n")
