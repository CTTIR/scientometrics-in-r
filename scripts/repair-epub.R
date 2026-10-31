# Correct known bookdown/Pandoc EPUB packaging defects, then verify atomically.
# Usage from the repository root:
# Rscript --vanilla scripts/repair-epub.R docs/scientometrics-in-r.epub
source(file.path("scripts", "verify-epub.R"))

sci_epub_read_text <- function(path) {
  rawToChar(readBin(path, "raw", n = file.info(path)$size))
}

sci_epub_empty_attributes <- function(text) {
  # Inspect actual opening tags and unquoted segments only. Text/code and
  # quoted attribute values must not be changed by the normalization.
  pattern <- "<[A-Za-z](?:[^'\">]|\"[^\"]*\"|'[^']*')*>"
  matches <- gregexpr(pattern, text, perl = TRUE)
  tags <- regmatches(text, matches)[[1L]]
  candidates <- grepl("(?<=\\s)(alt|style)(?![A-Za-z0-9_:.-])(?=\\s*(?:[A-Za-z_:]|/?>))", tags, perl = TRUE)
  fixed <- tags
  fixed[candidates] <- vapply(tags[candidates], function(tag) {
    pieces <- gregexpr("\"[^\"]*\"|'[^']*'|[^\"']+", tag, perl = TRUE)
    segments <- regmatches(tag, pieces)[[1L]]
    segments <- vapply(segments, function(segment) {
      if (grepl("^[\"']", segment)) return(segment)
      gsub("(?<=\\s)(alt|style)(?![A-Za-z0-9_:.-])(?=\\s*(?:[A-Za-z_:]|/?>))",
           '\\1=""', segment, perl = TRUE)
    }, character(1))
    paste0(segments, collapse = "")
  }, character(1))
  regmatches(text, matches) <- list(fixed)
  text
}

sci_epub_scope_table_ids <- function(documents) {
  changed <- character()
  repaired <- 0L
  reference_attrs <- c("headers", "aria-labelledby", "aria-describedby", "aria-controls",
                       "aria-owns", "aria-activedescendant", "for")
  for (member in names(documents)[grepl("\\.xhtml$", names(documents))]) {
    document <- documents[[member]]
    nodes <- xml2::xml_find_all(document, ".//*[@id]")
    ids <- xml2::xml_attr(nodes, "id")
    duplicates <- unique(ids[duplicated(ids)])
    if (!length(duplicates)) next
    tables <- xml2::xml_find_all(document, ".//*[local-name()='table']")
    table_paths <- xml2::xml_path(tables)
    for (id in duplicates) {
      headers <- nodes[ids == id]
      if (any(xml2::xml_name(headers) != "th") ||
          any(!grepl("(^| )gt_col_heading( |$)", xml2::xml_attr(headers, "class")))) {
        stop("Duplicate XML ID is not a scoped gt table heading: ", member, "#", id, call. = FALSE)
      }
      owners <- xml2::xml_find_first(headers, "ancestor::*[local-name()='table'][1]")
      owner_paths <- xml2::xml_path(owners)
      positions <- match(owner_paths, table_paths)
      if (anyNA(positions) || anyDuplicated(positions)) {
        stop("Duplicate gt heading within a single table: ", member, "#", id, call. = FALSE)
      }
      new_ids <- paste0("epub-table-", positions, "-", id)
      if (any(new_ids %in% ids)) stop("Scoped EPUB table ID collision.", call. = FALSE)
      # Links outside the owning table cannot identify which repeated heading
      # was intended. Reject them rather than silently selecting a target.
      for (other in names(documents)) {
        links <- xml2::xml_find_all(documents[[other]], ".//*[@href]")
        hrefs <- xml2::xml_attr(links, "href")
        candidates <- which(utils::URLdecode(sub("^.*#", "", hrefs)) == id & grepl("#", hrefs, fixed = TRUE))
        for (j in candidates) {
          ref <- sci_epub_reference(other, hrefs[j])
          if (is.null(ref) || ref$target != member) next
          owner <- xml2::xml_find_first(links[[j]], "ancestor::*[local-name()='table'][1]")
          position <- if (other == member) match(xml2::xml_path(owner), owner_paths) else NA_integer_
          if (is.na(position)) stop("Ambiguous link to repeated table heading: ", member, "#", id, call. = FALSE)
          xml2::xml_attr(links[[j]], "href") <- paste0("#", new_ids[position])
        }
      }
      for (attr in reference_attrs) {
        references <- xml2::xml_find_all(document, paste0(".//*[@", attr, "]"))
        for (node in references) {
          values <- strsplit(trimws(xml2::xml_attr(node, attr)), "[[:space:]]+")[[1L]]
          if (!id %in% values) next
          owner <- xml2::xml_find_first(node, "ancestor-or-self::*[local-name()='table'][1]")
          position <- match(xml2::xml_path(owner), owner_paths)
          if (is.na(position)) stop("Ambiguous ID reference to repeated table heading.", call. = FALSE)
          values[values == id] <- new_ids[position]
          xml2::xml_attr(node, attr) <- paste(values, collapse = " ")
        }
      }
      xml2::xml_attr(headers, "id") <- new_ids
      repaired <- repaired + length(headers)
    }
    changed <- c(changed, member)
  }
  list(changed = changed, repaired = repaired)
}

sci_epub_xhtml_styles <- function(documents) {
  changed <- character()
  moved <- dimensions <- alignments <- 0L
  visible_text <- function(document) {
    xml2::xml_text(xml2::xml_find_all(document,
      ".//*[local-name()='body']//text()[not(ancestor::*[local-name()='style' or local-name()='script'])]"))
  }
  for (member in names(documents)[grepl("\\.xhtml$", names(documents))]) {
    document <- documents[[member]]
    styles <- xml2::xml_find_all(document, ".//*[local-name()='style' and not(ancestor::*[local-name()='head'])]")
    images <- xml2::xml_find_all(document, ".//*[local-name()='img']")
    needs_dimension <- any(vapply(c("width", "height"), function(dimension) {
      values <- xml2::xml_attr(images, dimension)
      any(!is.na(values) & !grepl("^[0-9]+$", values))
    }, logical(1)))
    if (!length(styles) && !needs_dimension && all(is.na(xml2::xml_attr(images, "align")))) next
    before_text <- visible_text(document)
    before_css <- xml2::xml_text(xml2::xml_find_all(document, ".//*[local-name()='style']"))
    dirty <- FALSE
    if (length(styles)) {
      head <- xml2::xml_find_all(document, ".//*[local-name()='head']")
      if (length(head) != 1L) stop("Expected one XHTML head for style normalization.", call. = FALSE)
      for (style in styles) {
        xml2::xml_add_child(head[[1L]], style, .copy = TRUE)
        xml2::xml_remove(style)
      }
      moved <- moved + length(styles)
      dirty <- TRUE
    }
    for (image in images) {
      alignment <- xml2::xml_attr(image, "align")
      if (!is.na(alignment)) {
        if (!alignment %in% c("left", "right")) stop("Unsupported XHTML image alignment: ", alignment, call. = FALSE)
        style <- xml2::xml_attr(image, "style")
        if (is.na(style)) style <- ""
        if (!grepl("(^|;)\\s*float\\s*:", style, ignore.case = TRUE)) {
          style <- paste0(style, if (nzchar(style) && !grepl(";\\s*$", style)) ";" else "",
                          "float:", alignment, ";")
        }
        xml2::xml_attr(image, "style") <- style
        xml2::xml_attr(image, "align") <- NULL
        alignments <- alignments + 1L
        dirty <- TRUE
      }
      for (dimension in c("width", "height")) {
        value <- xml2::xml_attr(image, dimension)
        if (is.na(value) || grepl("^[0-9]+$", value)) next
        if (!grepl("^[0-9]+(?:\\.[0-9]+)?%$", value, perl = TRUE)) {
          stop("Unsupported XHTML image dimension: ", value, call. = FALSE)
        }
        style <- xml2::xml_attr(image, "style")
        if (is.na(style)) style <- ""
        # Existing inline CSS already overrides the HTML presentational hint.
        if (!grepl(paste0("(^|;)\\s*", dimension, "\\s*:"), style, ignore.case = TRUE)) {
          style <- paste0(style, if (nzchar(style) && !grepl(";\\s*$", style)) ";" else "",
                          dimension, ":", value, ";")
        }
        xml2::xml_attr(image, "style") <- style
        xml2::xml_attr(image, dimension) <- NULL
        dimensions <- dimensions + 1L
        dirty <- TRUE
      }
    }
    if (!identical(before_text, visible_text(document)) ||
        !identical(before_css, xml2::xml_text(xml2::xml_find_all(document, ".//*[local-name()='style']")))) {
      stop("XHTML styling normalization changed text or stylesheet contents.", call. = FALSE)
    }
    if (dirty) changed <- c(changed, member)
  }
  list(changed = changed, moved_styles = moved, css_dimensions = dimensions, css_alignments = alignments)
}

sci_repair_epub <- function(path, project_root = ".") {
  path <- normalizePath(path, mustWork = TRUE)
  project_root <- normalizePath(project_root, mustWork = TRUE)
  directory <- tempfile("epub-repair-")
  dir.create(directory)
  temporary <- tempfile("epub-verified-", tmpdir = dirname(path), fileext = ".epub")
  on.exit(unlink(c(directory, temporary), recursive = TRUE), add = TRUE)
  info <- sci_epub_extract(path, directory)
  members <- info$filename[info$type == "file"]
  changed <- character()
  for (member in members[grepl("\\.xhtml$", members)]) {
    file <- file.path(directory, member)
    original <- sci_epub_read_text(file)
    fixed <- sci_epub_empty_attributes(original)
    if (!identical(original, fixed)) {
      writeBin(charToRaw(fixed), file)
      changed <- c(changed, member)
    }
  }
  documents <- sci_epub_xml(directory, members)
  styling <- sci_epub_xhtml_styles(documents)
  scoped <- sci_epub_scope_table_ids(documents)
  ids <- sci_epub_ids(documents)
  link_repairs <- 0L
  for (member in names(documents)[grepl("\\.xhtml$", names(documents))]) {
    document <- documents[[member]]
    before_text <- xml2::xml_text(document)
    dirty <- member %in% c(scoped$changed, styling$changed)
    for (node in xml2::xml_find_all(document, ".//*[@href]")) {
      reference <- xml2::xml_attr(node, "href")
      if (!startsWith(reference, "#") || reference == "#") next
      fragment <- utils::URLdecode(substring(reference, 2L))
      if (fragment %in% ids[[member]]) next
      targets <- names(ids)[vapply(ids, function(x) fragment %in% x, logical(1))]
      if (length(targets) != 1L) {
        stop("Cannot uniquely resolve EPUB anchor ", reference, " from ", member,
             " (", length(targets), " targets).", call. = FALSE)
      }
      # Pandoc puts these chapter documents in a common text directory.
      # Refuse another layout rather than guessing a relative path.
      if (dirname(targets) != dirname(member)) stop("Unsupported cross-directory EPUB chapter link.", call. = FALSE)
      xml2::xml_attr(node, "href") <- paste0(basename(targets), reference)
      dirty <- TRUE
      link_repairs <- link_repairs + 1L
    }
    if (dirty) {
      file <- file.path(directory, member)
      xml2::write_xml(document, file, options = character())
      after <- xml2::read_xml(file, options = "NONET")
      if (!identical(before_text, xml2::xml_text(after))) stop("EPUB chapter text changed during link repair.", call. = FALSE)
      changed <- c(changed, member)
    }
  }

  container <- documents[["META-INF/container.xml"]]
  opf <- xml2::xml_attr(xml2::xml_find_all(container, ".//*[local-name()='rootfile']"), "full-path")
  if (length(opf) != 1L || !opf %in% names(documents)) stop("Invalid EPUB package declaration.", call. = FALSE)
  package <- documents[[opf]]
  manifest <- xml2::xml_find_first(package, ".//*[local-name()='manifest']")
  spine <- xml2::xml_find_first(package, ".//*[local-name()='spine']")
  assets <- c("text/LICENSE" = "LICENSE", "text/citation-files/citation.bib" = "citation.bib",
              "text/citation-files/citation.ris" = "citation.ris")
  asset_ids <- c("book-license", "citation-bib", "citation-ris")
  asset_titles <- c("Book licence", "Citation (BibTeX)", "Citation (RIS)")
  added <- 0L
  manifest_changed <- FALSE
  for (i in seq_along(assets)) {
    source <- file.path(project_root, assets[[i]])
    target_member <- sci_epub_path(paste(dirname(opf), names(assets)[i], sep = "/"))
    target <- file.path(directory, target_member)
    if (!file.exists(source)) stop("Required EPUB source asset is missing: ", source, call. = FALSE)
    if (file.exists(target)) {
      if (unname(tools::md5sum(source)) != unname(tools::md5sum(target))) {
        stop("Existing EPUB asset differs from its source: ", target_member, call. = FALSE)
      }
    } else {
      dir.create(dirname(target), recursive = TRUE, showWarnings = FALSE)
      if (!file.copy(source, target, copy.date = TRUE)) stop("Could not copy EPUB asset.", call. = FALSE)
      members <- c(members, target_member)
      changed <- c(changed, target_member)
      added <- added + 1L
    }
    items <- xml2::xml_children(manifest)
    matching <- which(xml2::xml_attr(items, "href") == names(assets)[i])
    if (!length(matching)) {
      if (asset_ids[i] %in% xml2::xml_attr(items, "id")) stop("EPUB asset manifest ID collision.", call. = FALSE)
      item <- xml2::read_xml(paste0('<item xmlns="http://www.idpf.org/2007/opf" id="',
        asset_ids[i], '" href="', names(assets)[i], '" media-type="text/plain"/>'))
      xml2::xml_add_child(manifest, item)
      manifest_changed <- TRUE
    }
    items <- xml2::xml_children(manifest)
    matching <- which(xml2::xml_attr(items, "href") == names(assets)[i])
    if (length(matching) != 1L) stop("Duplicate EPUB asset manifest entry.", call. = FALSE)
    asset_item <- items[[matching]]
    asset_id <- xml2::xml_attr(asset_item, "id")
    fallback_id <- paste0(asset_ids[i], "-readable")
    fallback_href <- paste0(names(assets)[i], ".xhtml")
    fallback_member <- paste0(target_member, ".xhtml")
    fallback_path <- file.path(directory, fallback_member)
    source_text <- sci_epub_read_text(source)
    if (file.exists(fallback_path)) {
      fallback <- xml2::read_xml(fallback_path, options = "NONET")
      text <- xml2::xml_text(xml2::xml_find_first(fallback, ".//*[local-name()='pre']"))
      if (!identical(text, source_text)) stop("Existing EPUB fallback differs from its source asset.", call. = FALSE)
    } else {
      fallback <- xml2::read_xml(paste0(
        '<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en"><head><title>', asset_titles[i],
        '</title><style type="text/css">body { margin: 1em; } pre { white-space: pre-wrap; overflow-wrap: break-word; word-wrap: break-word; }</style></head><body><h1>',
        asset_titles[i], '</h1><pre></pre></body></html>'))
      pre <- xml2::xml_find_first(fallback, ".//*[local-name()='pre']")
      xml2::xml_text(pre) <- source_text
      xml2::write_xml(fallback, fallback_path, options = character())
      members <- c(members, fallback_member)
      changed <- c(changed, fallback_member)
    }
    fallback_items <- which(xml2::xml_attr(items, "id") == fallback_id)
    if (!length(fallback_items)) {
      item <- xml2::read_xml(paste0('<item xmlns="http://www.idpf.org/2007/opf" id="', fallback_id,
        '" href="', fallback_href, '" media-type="application/xhtml+xml"/>'))
      xml2::xml_add_child(manifest, item)
      manifest_changed <- TRUE
    } else if (length(fallback_items) != 1L || xml2::xml_attr(items[[fallback_items]], "href") != fallback_href) {
      stop("EPUB fallback manifest ID collision.", call. = FALSE)
    }
    current_fallback <- xml2::xml_attr(asset_item, "fallback")
    if (is.na(current_fallback)) {
      xml2::xml_attr(asset_item, "fallback") <- fallback_id
      manifest_changed <- TRUE
    } else if (current_fallback != fallback_id) stop("Unexpected EPUB asset fallback.", call. = FALSE)
    itemrefs <- xml2::xml_children(spine)
    matching_spine <- which(xml2::xml_attr(itemrefs, "idref") == asset_id)
    if (!length(matching_spine)) {
      itemref <- xml2::read_xml(paste0('<itemref xmlns="http://www.idpf.org/2007/opf" idref="', asset_id, '" linear="no"/>'))
      xml2::xml_add_child(spine, itemref)
      manifest_changed <- TRUE
    } else if (length(matching_spine) != 1L || xml2::xml_attr(itemrefs[[matching_spine]], "linear") != "no") {
      stop("Unexpected EPUB asset spine entry.", call. = FALSE)
    }
  }
  if (manifest_changed) {
    xml2::write_xml(package, file.path(directory, opf), options = character())
    changed <- c(changed, opf)
  }
  if (!length(changed)) {
    sci_verify_epub(path)
    cat("EPUB repair: already valid; archive left byte-for-byte unchanged.\n")
    return(invisible(list(changed = character(), repaired_links = 0L, added_assets = 0L)))
  }
  # Preserve every unrelated member's bytes, including metadata and media.
  zip::zipr(temporary, "mimetype", root = directory, compression_level = 0,
            include_directories = FALSE)
  zip::zip_append(temporary, setdiff(members, "mimetype"), root = directory,
                  compression_level = 9, include_directories = FALSE)
  verified <- sci_verify_epub(temporary)
  if (!file.rename(temporary, path)) stop("Could not atomically replace EPUB; original retained.", call. = FALSE)
  cat("EPUB repair:", link_repairs, "cross-chapter links;", scoped$repaired, "table header IDs;",
      styling$moved_styles, "styles moved to head;", styling$css_dimensions, "CSS image dimensions;",
      styling$css_alignments, "CSS image alignments;", added,
      "source assets bundled;", length(unique(changed)), "members changed.\n")
  invisible(list(changed = unique(changed), repaired_links = link_repairs, table_header_ids = scoped$repaired,
                 moved_styles = styling$moved_styles, css_dimensions = styling$css_dimensions,
                 css_alignments = styling$css_alignments,
                 added_assets = added, validation = verified))
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) != 1L) stop("Usage: Rscript scripts/repair-epub.R book.epub", call. = FALSE)
  sci_repair_epub(args[[1L]])
}
