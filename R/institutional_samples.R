# Descriptive summaries for the institution-specific samples in Chapter 13.
# The pooled reference adjusts for publication year only, not field or document age
# at a fixed citation window. It is not MNCS or a population benchmark.
sci_institution_citation_rows <- function(works) {
  required <- c("id", "publication_date", "cited_by_count")
  if (!is.data.frame(works) || !all(required %in% names(works)) || !nrow(works)) {
    stop("Each institutional sample needs work IDs, dates and citation counts.")
  }
  if (anyNA(works$id) || any(!nzchar(works$id)) || anyDuplicated(works$id)) {
    stop("Work IDs must be present and unique within each institutional sample.")
  }
  cites <- works$cited_by_count
  if (!is.numeric(cites) || any(!is.na(cites) & (!is.finite(cites) | cites < 0))) {
    stop("Citation counts must be nonnegative finite numbers or missing.")
  }
  dates <- as.character(works$publication_date)
  year <- rep(NA_integer_, length(dates))
  valid <- !is.na(dates) & grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", dates)
  year[valid] <- as.integer(substr(dates[valid], 1, 4))
  data.frame(id = works$id, year = year, citations = cites)
}

sci_pooled_year_reference <- function(samples) {
  if (!is.list(samples) || !length(samples)) stop("Provide institutional samples.")
  pooled <- unique(do.call(rbind, lapply(samples, sci_institution_citation_rows)))
  if (anyDuplicated(pooled$id)) {
    stop("Shared works have inconsistent snapshots; reconcile them before comparison.")
  }
  pooled <- pooled[!is.na(pooled$year) & !is.na(pooled$citations), , drop = FALSE]
  if (!nrow(pooled)) stop("The pooled sample has no usable citation/year observations.")
  reference <- stats::aggregate(citations ~ year, pooled, mean)
  names(reference)[2] <- "pooled_year_mean"
  reference
}

sci_sample_citation_summary <- function(works, reference) {
  rows <- sci_institution_citation_rows(works)
  denominator <- reference$pooled_year_mean[match(rows$year, reference$year)]
  usable <- !is.na(rows$citations) & is.finite(denominator) & denominator > 0
  observed <- rows$citations[!is.na(rows$citations)]
  data.frame(
    n_sampled = nrow(rows), n_citation_observed = length(observed),
    mean_cites = if (length(observed)) mean(observed) else NA_real_,
    median_cites = if (length(observed)) stats::median(observed) else NA_real_,
    n_ratio_observed = sum(usable),
    pooled_year_ratio = if (any(usable)) {
      mean(rows$citations[usable] / denominator[usable])
    } else {
      NA_real_
    }
  )
}

sci_institution_sample_counts <- function(works, institution_id) {
  if (
    !is.data.frame(works) || !all(c("id", "authorships") %in% names(works)) ||
      !nrow(works) || anyNA(works$id) || anyDuplicated(works$id)
  ) {
    stop("Counting needs a nonempty sample with unique work IDs and authorships.")
  }
  short_id <- function(x) sub("^https?://openalex.org/", "", as.character(x))
  target <- short_id(institution_id)
  if (length(target) != 1L || is.na(target) || !grepl("^I[0-9]+$", target)) {
    stop("Use one OpenAlex institution ID.")
  }
  number <- vapply(works$authorships, function(authors) {
    if (
      !is.data.frame(authors) || !nrow(authors) ||
        !"affiliations" %in% names(authors)
    ) {
      return(NA_integer_)
    }
    # Missing affiliations for even one author leave the work's institution
    # denominator unknown; a known target affiliation cannot fill that gap.
    per_author <- lapply(authors$affiliations, function(affiliations) {
      if (
        !is.data.frame(affiliations) || !nrow(affiliations) ||
          !"id" %in% names(affiliations)
      ) {
        return(NULL)
      }
      ids <- short_id(affiliations$id)
      if (anyNA(ids) || any(!grepl("^I[0-9]+$", ids))) {
        return(NULL)
      }
      unique(ids)
    })
    if (any(lengths(per_author) == 0L)) {
      return(NA_integer_)
    }
    ids <- unique(unlist(per_author, use.names = FALSE))
    if (!length(ids) || !target %in% ids) {
      return(NA_integer_)
    }
    length(ids)
  }, integer(1))
  complete <- !is.na(number)
  data.frame(
    full_count = nrow(works), affiliation_covered = sum(complete),
    frac_count = if (all(complete)) sum(1 / number) else NA_real_
  )
}
