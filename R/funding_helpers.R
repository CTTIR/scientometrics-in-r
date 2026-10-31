# Normalize current OpenAlex funder metadata without treating missing entries
# as evidence that a publication had no financial support.
sci_funder_rows <- function(funders) {
  empty <- data.frame(id = character(), display_name = character())
  if (
    is.null(funders) || length(funders) == 0L ||
      (is.atomic(funders) && all(is.na(funders)))
  ) {
    return(empty)
  }
  if (!is.data.frame(funders)) {
    stop("Funder metadata must be a data frame or an empty/missing entry.",
      call. = FALSE
    )
  }
  if (!nrow(funders)) {
    return(empty)
  }
  if (!"id" %in% names(funders)) {
    stop("Funder metadata needs an id column.", call. = FALSE)
  }
  ids <- as.character(funders$id)
  keep <- !is.na(ids) & nzchar(trimws(ids))
  ids <- ids[keep]
  labels <- if ("display_name" %in% names(funders)) {
    as.character(funders$display_name)[keep]
  } else {
    rep(NA_character_, length(ids))
  }
  missing_label <- is.na(labels) | !nzchar(trimws(labels))
  labels[missing_label] <- ids[missing_label]
  rows <- data.frame(id = ids, display_name = labels)
  rows[!duplicated(rows$id), , drop = FALSE]
}
