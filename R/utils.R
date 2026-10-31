#' Deduplicate records by DOI
#'
#' Removes duplicate rows based on the `doi` column, keeping the first
#' occurrence. Rows with missing DOIs are always kept.
#'
#' @param df A data frame with a `doi` column.
#' @return A deduplicated tibble.
#' @export
dedupe_by_doi <- function(df) {
  stopifnot("doi" %in% names(df))
  has_doi <- !is.na(df$doi) & nzchar(df$doi)
  deduped <- df[has_doi, ]
  deduped <- deduped[!duplicated(deduped$doi), ]
  no_doi <- df[!has_doi, ]
  dplyr::bind_rows(deduped, no_doi)
}

#' Compute the h-index from a citation vector
#'
#' @param citations An integer vector of citation counts.
#' @return A single integer: the h-index.
#' @export
compute_h_index <- function(citations) {
  stopifnot(is.numeric(citations))
  citations <- sort(citations, decreasing = TRUE)
  n <- length(citations)
  if (n == 0L) {
    return(0L)
  }
  h <- sum(citations >= seq_along(citations))
  as.integer(h)
}

#' Field-normalize citation counts (MNCS)
#'
#' Computes the Mean Normalized Citation Score by dividing each paper's
#' citation count by the field mean for its publication year.
#'
#' @param citations Numeric vector of citation counts.
#' @param field_means Numeric vector of field mean citation counts
#'   (same length as `citations`).
#' @return A numeric vector of normalized citation scores.
#' @export
field_normalize <- function(citations, field_means) {
  stopifnot(
    is.numeric(citations),
    is.numeric(field_means),
    length(citations) == length(field_means)
  )
  ifelse(field_means == 0, NA_real_, citations / field_means)
}

#' Compute Mean Normalized Citation Score
#'
#' Wrapper around [field_normalize()] that computes the MNCS for a data frame
#' containing citation counts, field identifiers, and publication years.
#'
#' @param df A data frame with columns `cited_by_count`, `field`, and `year`.
#' @return The input data frame with an added `mncs` column.
#' @importFrom rlang .data
#' @export
compute_mncs <- function(df) {
  required <- c("cited_by_count", "field", "year")
  stopifnot(all(required %in% names(df)))
  df <- dplyr::group_by(df, .data$field, .data$year)
  df <- dplyr::mutate(
    df,
    field_mean = mean(.data$cited_by_count, na.rm = TRUE),
    mncs = field_normalize(.data$cited_by_count, .data$field_mean)
  )
  dplyr::ungroup(df)
}

#' Build a co-authorship network from bibliometric data
#'
#' Constructs an undirected, weighted co-authorship graph from a data frame
#' of works with author information.
#'
#' @param works A data frame with `id` and an `authorships` list-column.
#'   Nested author data may use current OpenAlex `id`/`display_name`, legacy
#'   `au_id`/`au_display_name`, or flattened `author.id`/`author.display_name`.
#' @return An undirected [igraph::graph] with stable author IDs in the `name`
#'   vertex attribute, display names in `label` and `display_name`, and distinct
#'   jointly authored work counts in the `weight` edge attribute. Use `label`
#'   for human-readable plot labels; different authors may share a display name.
#' @export
build_coauth_graph <- function(works) {
  stopifnot("id" %in% names(works), "authorships" %in% names(works))
  authors <- tidyr::unnest(dplyr::select(works, work_id = "id", "authorships"),
    "authorships",
    names_sep = "_"
  )
  if (!nrow(authors)) {
    return(igraph::make_empty_graph(directed = FALSE))
  }
  id_col <- intersect(
    c("authorships_id", "authorships_au_id", "authorships_author.id"),
    names(authors)
  )[1]
  name_col <- intersect(c(
    "authorships_display_name", "authorships_au_display_name",
    "authorships_author.display_name"
  ), names(authors))[1]
  if (is.na(id_col)) stop("Authorships need a supported author ID field.", call. = FALSE)
  authors <- tibble::tibble(
    work_id = authors$work_id,
    author_id = as.character(authors[[id_col]]),
    display_name = if (is.na(name_col)) {
      NA_character_
    } else {
      as.character(authors[[name_col]])
    }
  )
  authors <- dplyr::filter(
    authors, !is.na(.data$work_id), !is.na(.data$author_id),
    nzchar(.data$author_id)
  )
  membership <- dplyr::distinct(authors, .data$work_id, .data$author_id)
  edges <- dplyr::inner_join(membership, membership,
    by = "work_id",
    suffix = c("_a", "_b"), relationship = "many-to-many"
  )
  edges <- dplyr::filter(edges, .data$author_id_a < .data$author_id_b)
  edges <- dplyr::count(edges, .data$author_id_a, .data$author_id_b, name = "weight")
  ids <- unique(authors$author_id)
  labels <- vapply(ids, function(id) {
    names <- authors$display_name[authors$author_id == id]
    names <- names[!is.na(names) & nzchar(names)]
    if (length(names)) names[1] else id
  }, character(1), USE.NAMES = FALSE)
  vertices <- data.frame(name = ids, label = labels, display_name = labels)
  igraph::graph_from_data_frame(edges, directed = FALSE, vertices = vertices)
}

#' Detect Kleinberg keyword bursts
#'
#' Applies Kleinberg's burst detection algorithm to a time series of keyword
#' frequencies. Requires the `bursts` package.
#'
#' @param keywords A character vector of keywords (one per document).
#' @param dates A Date vector of publication dates (same length as `keywords`).
#' @param top_n Number of top keywords to analyse (default 50).
#' @param gamma Difficulty of transitioning between states (default 1.0).
#' @return A data frame with columns `keyword`, `level`, `start`, and `end`.
#' @export
kleinberg_bursts <- function(keywords, dates, top_n = 50, gamma = 1.0) {
  stopifnot(length(keywords) == length(dates))

  df <- tibble::tibble(keyword = keywords, date = dates)
  df <- dplyr::filter(df, !is.na(.data$keyword), !is.na(.data$date))

  top_kw <- dplyr::count(df, .data$keyword, sort = TRUE)
  top_kw <- utils::head(top_kw, top_n)

  results <- lapply(top_kw$keyword, function(kw) {
    kw_dates <- sort(df$date[df$keyword == kw])
    if (length(kw_dates) < 3) {
      return(NULL)
    }
    offsets <- as.numeric(difftime(kw_dates, min(kw_dates), units = "days"))
    if (all(offsets == 0)) {
      return(NULL)
    }
    tryCatch(
      {
        b <- bursts::kleinberg(offsets, gamma = gamma)
        b$keyword <- kw
        b
      },
      error = function(e) NULL
    )
  })

  dplyr::bind_rows(results)
}
