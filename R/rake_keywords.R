#' Rank keyword phrases with RAKE degree/frequency scores
#'
#' Splits a single document at stopwords, punctuation and numeric tokens.
#' Candidate phrases retain contiguous words (including internal apostrophes
#' and hyphens). Word degree includes the word itself, so each occurrence in a
#' phrase of length m contributes m. Phrase scores sum word degree/frequency.
#' Repeated phrases are returned once, with an occurrence count; ties are sorted
#' by phrase. This is the basic candidate-scoring procedure, without the optional
#' adjoining-keyword postprocessing in Rose et al. (2010).
#'
#' @param text One non-missing character string.
#' @param stopwords Character vector of word delimiters; specify a language-
#'   appropriate list, for example `stopwords::stopwords("en")`.
#' @param n_keywords Maximum positive integer number of phrases to return.
#' @return A tibble with `keyword`, `score` and `frequency` columns.
#' @references Rose, S., Engel, D., Cramer, N. and Cowley, W. (2010).
#'   Automatic Keyword Extraction from Individual Documents.
#'   <https://doi.org/10.1002/9780470689646.ch1>.
#' @examples
#' rake_keywords("red apple and red apple pie. apple", "and", 3)
rake_keywords <- function(text, stopwords, n_keywords = 10L) {
  if (!is.character(text) || length(text) != 1L || is.na(text)) {
    stop("`text` must be one non-missing string.", call. = FALSE)
  }
  if (!is.character(stopwords) || anyNA(stopwords)) {
    stop("`stopwords` must be a non-missing character vector.", call. = FALSE)
  }
  if (
    !is.numeric(n_keywords) || length(n_keywords) != 1L ||
      !is.finite(n_keywords) || n_keywords < 1 || n_keywords != floor(n_keywords) ||
      n_keywords > .Machine$integer.max
  ) {
    stop("`n_keywords` must be a positive integer.", call. = FALSE)
  }
  empty <- tibble::tibble(keyword = character(), score = numeric(), frequency = integer())
  tokens <- regmatches(tolower(text), gregexpr(
    "[[:alpha:]]+(?:[-'][[:alpha:]]+)*|[^[:space:]]", tolower(text),
    perl = TRUE
  ))[[1]]
  if (!length(tokens)) {
    return(empty)
  }
  boundary <- !grepl("^[[:alpha:]]", tokens) | tokens %in% tolower(stopwords)
  phrases <- split(tokens[!boundary], cumsum(boundary)[!boundary])
  if (!length(phrases)) {
    return(empty)
  }
  counts <- table(unlist(phrases, use.names = FALSE))
  degree <- stats::setNames(numeric(length(counts)), names(counts))
  for (phrase in phrases) {
    local <- table(phrase)
    degree[names(local)] <- degree[names(local)] + as.numeric(local) * length(phrase)
  }
  word_score <- degree / as.numeric(counts)
  labels <- vapply(phrases, paste, collapse = " ", character(1))
  occurrences <- table(labels)
  distinct <- !duplicated(labels)
  scores <- vapply(phrases[distinct], function(words) sum(word_score[words]), numeric(1))
  result <- tibble::tibble(
    keyword = unname(labels[distinct]), score = unname(scores),
    frequency = as.integer(occurrences[labels[distinct]])
  )
  result <- result[order(-result$score, result$keyword), , drop = FALSE]
  utils::head(result, n_keywords)
}
