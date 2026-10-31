# Verify a packaged EPUB without running chapters or requesting network data.
# Usage: Rscript --vanilla scripts/verify-epub.R docs/scientometrics-in-r.epub
sci_epub_dependencies <- function() {
  for (package in c("xml2", "zip", "digest")) {
    if (!requireNamespace(package, quietly = TRUE)) {
      stop("EPUB packaging requires the R package '", package, "'.", call. = FALSE)
    }
  }
}

sci_epub_path <- function(path) {
  if (grepl("^(?:/|[A-Za-z]:)|\\\\", path, perl = TRUE)) {
    stop("Unsafe EPUB member path: ", path, call. = FALSE)
  }
  result <- character()
  for (part in strsplit(path, "/", fixed = TRUE)[[1L]]) {
    if (part %in% c("", ".")) next
    if (part == "..") {
      if (!length(result)) stop("EPUB reference escapes its archive: ", path, call. = FALSE)
      result <- head(result, -1L)
    } else result <- c(result, part)
  }
  paste(result, collapse = "/")
}

sci_epub_reference <- function(member, reference) {
  if (grepl("^[A-Za-z][A-Za-z0-9+.-]*:|^//", reference)) return(NULL)
  hash <- regexpr("#", reference, fixed = TRUE)[1L]
  fragment <- if (hash > 0L) utils::URLdecode(substring(reference, hash + 1L)) else ""
  path <- if (hash > 0L) substring(reference, 1L, hash - 1L) else reference
  path <- utils::URLdecode(sub("\\?.*$", "", path))
  target <- if (nzchar(path)) sci_epub_path(paste(dirname(member), path, sep = "/")) else member
  list(target = target, fragment = fragment)
}

sci_epub_extract <- function(path, directory) {
  sci_epub_dependencies()
  info <- zip::zip_list(path)
  if (!nrow(info) || anyDuplicated(info$filename)) stop("Empty or duplicate EPUB ZIP members.", call. = FALSE)
  normalized <- vapply(info$filename, sci_epub_path, character(1))
  if (any(normalized != sub("/$", "", info$filename))) {
    stop("Non-canonical EPUB member path.", call. = FALSE)
  }
  if (any(!info$type %in% c("file", "directory"))) stop("Unsupported EPUB ZIP member type.", call. = FALSE)
  con <- file(path, "rb")
  header <- readBin(con, "raw", n = 30L)
  close(con)
  if (length(header) != 30L || !identical(as.integer(header[1:4]), c(80L, 75L, 3L, 4L)) ||
      info$filename[1L] != "mimetype" || any(as.integer(header[9:10]) != 0L) ||
      any(as.integer(header[29:30]) != 0L)) {
    stop("EPUB mimetype must be the first, uncompressed ZIP member without extra fields.", call. = FALSE)
  }
  zip::unzip(path, exdir = directory)
  files <- info[info$type == "file", , drop = FALSE]
  actual <- vapply(file.path(directory, files$filename), function(file) {
    digest::digest(file = file, algo = "crc32", serialize = FALSE)
  }, character(1))
  expected <- sprintf("%08s", as.character(files$crc32))
  expected <- gsub(" ", "0", expected, fixed = TRUE)
  if (any(tolower(actual) != tolower(expected))) stop("EPUB ZIP CRC mismatch.", call. = FALSE)
  mime <- readBin(file.path(directory, "mimetype"), "raw", n = 100L)
  if (!identical(mime, charToRaw("application/epub+zip"))) stop("Invalid EPUB mimetype content.", call. = FALSE)
  info
}

sci_epub_xml <- function(directory, members) {
  paths <- members[grepl("\\.(xhtml|opf|ncx|xml)$", members)]
  documents <- lapply(paths, function(path) {
    tryCatch(xml2::read_xml(file.path(directory, path), options = "NONET"),
             error = function(e) stop("Invalid XML in ", path, ": ", conditionMessage(e), call. = FALSE))
  })
  names(documents) <- paths
  documents
}

sci_epub_ids <- function(documents) {
  lapply(names(documents), function(member) {
    ids <- xml2::xml_attr(xml2::xml_find_all(documents[[member]], ".//*[@id]"), "id")
    if (anyDuplicated(ids)) stop("Duplicate XML IDs in ", member, call. = FALSE)
    ids
  }) |> stats::setNames(names(documents))
}

sci_verify_epub <- function(path, quiet = FALSE) {
  path <- normalizePath(path, mustWork = TRUE)
  directory <- tempfile("epub-check-")
  dir.create(directory)
  on.exit(unlink(directory, recursive = TRUE), add = TRUE)
  info <- sci_epub_extract(path, directory)
  members <- info$filename[info$type == "file"]
  documents <- sci_epub_xml(directory, members)
  ids <- sci_epub_ids(documents)
  references <- 0L
  for (member in names(documents)) {
    if (grepl("\\.xhtml$", member)) {
      misplaced <- xml2::xml_find_all(documents[[member]], ".//*[local-name()='style' and not(ancestor::*[local-name()='head'])]")
      if (length(misplaced)) stop("XHTML stylesheet outside head: ", member, call. = FALSE)
      aligned <- xml2::xml_find_all(documents[[member]], ".//*[local-name()='img' and @align]")
      if (length(aligned)) stop("Obsolete XHTML image alignment: ", member, call. = FALSE)
      for (dimension in c("width", "height")) {
        values <- xml2::xml_attr(xml2::xml_find_all(documents[[member]], ".//*[local-name()='img']"), dimension)
        if (any(!is.na(values) & !grepl("^[0-9]+$", values))) stop("Invalid XHTML image dimension: ", member, call. = FALSE)
      }
    }
    nodes <- xml2::xml_find_all(documents[[member]], ".//*[@href or @src or @*[local-name()='href']]")
    for (node in nodes) {
      attrs <- xml2::xml_attrs(node)
      values <- attrs[sub("^.*:", "", names(attrs)) %in% c("href", "src")]
      for (reference in values) {
        ref <- sci_epub_reference(member, reference)
        if (is.null(ref)) next
        references <- references + 1L
        if (!ref$target %in% members) stop("Missing EPUB member: ", member, " -> ", reference, call. = FALSE)
        if (nzchar(ref$fragment) && ref$target %in% names(ids) && !ref$fragment %in% ids[[ref$target]]) {
          stop("Missing EPUB anchor: ", member, " -> ", reference, call. = FALSE)
        }
      }
    }
  }
  container <- documents[["META-INF/container.xml"]]
  if (is.null(container)) stop("EPUB container.xml is missing.", call. = FALSE)
  opf <- xml2::xml_attr(xml2::xml_find_all(container, ".//*[local-name()='rootfile']"), "full-path")
  if (length(opf) != 1L || !opf %in% names(documents)) stop("EPUB must declare one existing package document.", call. = FALSE)
  package <- documents[[opf]]
  manifest <- xml2::xml_find_all(package, ".//*[local-name()='manifest']/*[local-name()='item']")
  manifest_ids <- xml2::xml_attr(manifest, "id")
  if (anyNA(manifest_ids) || anyDuplicated(manifest_ids)) stop("Invalid EPUB manifest identifiers.", call. = FALSE)
  spine <- xml2::xml_attr(xml2::xml_find_all(package, ".//*[local-name()='spine']/*[local-name()='itemref']"), "idref")
  if (!length(spine) || any(!spine %in% manifest_ids)) stop("Invalid EPUB spine references.", call. = FALSE)
  fallbacks <- xml2::xml_attr(manifest, "fallback")
  if (any(!is.na(fallbacks) & !fallbacks %in% manifest_ids)) stop("Missing EPUB manifest fallback.", call. = FALSE)
  media <- xml2::xml_attr(manifest, "media-type")
  for (id in spine) {
    seen <- character()
    repeat {
      if (id %in% seen) stop("Cyclic EPUB manifest fallback.", call. = FALSE)
      seen <- c(seen, id)
      position <- match(id, manifest_ids)
      if (media[position] %in% c("application/xhtml+xml", "image/svg+xml")) break
      id <- fallbacks[position]
      if (is.na(id)) stop("Nonstandard EPUB spine item needs a readable fallback.", call. = FALSE)
    }
  }
  result <- list(file = path, members = length(members), xhtml = sum(grepl("\\.xhtml$", members)),
                 local_references = references, spine_items = length(spine), crc = "passed",
                 xml = "passed", mimetype = "passed", internal_links = "passed")
  if (!quiet) cat("EPUB verified:", result$members, "members,", result$xhtml, "XHTML files,",
                  references, "local references; CRC, XML, spine and mimetype passed.\n")
  invisible(result)
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) != 1L) stop("Usage: Rscript scripts/verify-epub.R book.epub", call. = FALSE)
  sci_verify_epub(args[[1L]])
}
