# Offline packaging regression checks; no book render or network access.
# Run from the repository root: Rscript scripts/test-epub-packaging.R
source("scripts/repair-epub.R")
fixture <- tempfile("epub-packaging-test-")
dir.create(fixture)
checks <- 0L
check <- function(value) {
  stopifnot(isTRUE(value))
  checks <<- checks + 1L
}
fails <- function(expr, pattern) {
  error <- tryCatch({ force(expr); NULL }, error = identity)
  check(inherits(error, "error") && grepl(pattern, conditionMessage(error)))
}
make_fixture <- function(name, target = "target", duplicate = FALSE, tables = FALSE, ambiguous_table_link = FALSE) {
  directory <- file.path(fixture, name)
  dir.create(file.path(directory, "META-INF"), recursive = TRUE)
  dir.create(file.path(directory, "EPUB", "text"), recursive = TRUE)
  writeBin(charToRaw("application/epub+zip"), file.path(directory, "mimetype"))
  writeLines('<container xmlns="urn:oasis:names:tc:opendocument:xmlns:container" version="1.0"><rootfiles><rootfile full-path="EPUB/content.opf" media-type="application/oebps-package+xml"/></rootfiles></container>',
             file.path(directory, "META-INF", "container.xml"))
  table_content <- if (tables) paste0(
    '<table><tr><th class="gt_col_heading" id="value">First</th></tr><tr><td headers="value" aria-describedby="value"><a href="#value">One</a></td></tr></table>',
    '<table><tr><th class="gt_col_heading" id="value">Second</th></tr><tr><td headers="value" aria-labelledby="value">Two</td></tr></table>',
    if (ambiguous_table_link) '<a href="#value">Which table?</a>' else "") else ""
  writeLines(paste0('<html xmlns="http://www.w3.org/1999/xhtml"><head><title>A</title></head><body><h1 id="a">A</h1>',
    '<style type="text/css">.example { color: red; }</style><img alt="fixture" width="90%" style="border:0" src="data:image/png;base64,AA=="/>', table_content,
    '<p style>Keep exact scholarly content &amp; symbols.</p><a href="#', target,
    '">Target</a><a href="#a">Local</a><a href="https://example.com/">External</a><p title="alt style">&lt;img alt&gt;</p><a href="citation-files/citation.bib">Citation</a></body></html>'),
    file.path(directory, "EPUB", "text", "a.xhtml"))
  writeLines('<html xmlns="http://www.w3.org/1999/xhtml"><head><title>B</title></head><body><h1 id="target">B</h1></body></html>',
             file.path(directory, "EPUB", "text", "b.xhtml"))
  if (duplicate) file.copy(file.path(directory, "EPUB", "text", "b.xhtml"), file.path(directory, "EPUB", "text", "c.xhtml"))
  writeLines('<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="id"><metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:identifier id="id">fixture</dc:identifier><dc:title>Fixture</dc:title><dc:language>en</dc:language></metadata><manifest><item id="a" href="text/a.xhtml" media-type="application/xhtml+xml"/><item id="b" href="text/b.xhtml" media-type="application/xhtml+xml"/></manifest><spine><itemref idref="a"/><itemref idref="b"/></spine></package>',
             file.path(directory, "EPUB", "content.opf"))
  path <- file.path(fixture, paste0(name, ".epub"))
  zip::zipr(path, "mimetype", root = directory, compression_level = 0, include_directories = FALSE)
  zip::zip_append(path, c("META-INF/container.xml", "EPUB/content.opf", "EPUB/text/a.xhtml", "EPUB/text/b.xhtml",
                          if (duplicate) "EPUB/text/c.xhtml"), root = directory, include_directories = FALSE)
  path
}
tryCatch({
  for (asset in c("LICENSE", "citation.bib", "citation.ris")) writeLines(paste("Fixture", asset), file.path(fixture, asset))
  check(identical(sci_epub_empty_attributes('<img alt class="cover"/>'), '<img alt="" class="cover"/>'))
  check(identical(sci_epub_empty_attributes('<td style>data</td>'), '<td style="">data</td>'))
  unchanged <- '<p title="alt style" style="color:red">&lt;img alt&gt;</p>'
  check(identical(sci_epub_empty_attributes(unchanged), unchanged))
  fails(sci_epub_path("../secret"), "escapes")
  fails(sci_epub_path("/absolute"), "Unsafe")
  fails(sci_epub_path("C:/absolute"), "Unsafe")
  fails(sci_epub_path("..\\secret"), "Unsafe")
  path <- make_fixture("valid")
  result <- sci_repair_epub(path, fixture)
  check(result$repaired_links == 1L && result$added_assets == 3L)
  check(result$moved_styles == 1L && result$css_dimensions == 1L)
  checked <- sci_verify_epub(path, quiet = TRUE)
  check(checked$internal_links == "passed")
  extract <- tempfile(tmpdir = fixture)
  dir.create(extract)
  sci_epub_extract(path, extract)
  xml <- xml2::read_xml(file.path(extract, "EPUB/text/a.xhtml"))
  check("b.xhtml#target" %in% xml2::xml_attr(xml2::xml_find_all(xml, ".//*[@href]"), "href"))
  check(grepl("Keep exact scholarly content & symbols.", xml2::xml_text(xml), fixed = TRUE))
  check(xml2::xml_text(xml2::xml_find_first(xml, ".//*[local-name()='head']/*[local-name()='style']")) == ".example { color: red; }")
  image <- xml2::xml_find_first(xml, ".//*[local-name()='img']")
  check(is.na(xml2::xml_attr(image, "width")) && xml2::xml_attr(image, "style") == "border:0;width:90%;")
  check(identical(readBin(file.path(extract, "EPUB/text/citation-files/citation.bib"), "raw", n = 1000L),
                  readBin(file.path(fixture, "citation.bib"), "raw", n = 1000L)))
  readable <- xml2::read_xml(file.path(extract, "EPUB/text/citation-files/citation.bib.xhtml"))
  check(identical(xml2::xml_text(xml2::xml_find_first(readable, ".//*[local-name()='pre']")),
                  sci_epub_read_text(file.path(fixture, "citation.bib"))))
  package <- xml2::read_xml(file.path(extract, "EPUB/content.opf"))
  check(length(xml2::xml_find_all(package, ".//*[local-name()='itemref' and @linear='no']")) == 3L)
  styled <- xml2::read_xml('<html xmlns="http://www.w3.org/1999/xhtml"><head/><body><img width="90%" style="width:20rem"/></body></html>')
  sci_epub_xhtml_styles(list("style.xhtml" = styled))
  check(xml2::xml_attr(xml2::xml_find_first(styled, ".//*[local-name()='img']"), "style") == "width:20rem")
  aligned <- xml2::read_xml('<html xmlns="http://www.w3.org/1999/xhtml"><head/><body><img align="right" alt="cover"/></body></html>')
  aligned_result <- sci_epub_xhtml_styles(list("align.xhtml" = aligned))
  aligned_image <- xml2::xml_find_first(aligned, ".//*[local-name()='img']")
  check(aligned_result$css_alignments == 1L && is.na(xml2::xml_attr(aligned_image, "align")) &&
          xml2::xml_attr(aligned_image, "style") == "float:right;")
  aligned_override <- xml2::read_xml('<html xmlns="http://www.w3.org/1999/xhtml"><head/><body><img align="right" style="float:left"/></body></html>')
  sci_epub_xhtml_styles(list("align.xhtml" = aligned_override))
  check(xml2::xml_attr(xml2::xml_find_first(aligned_override, ".//*[local-name()='img']"), "style") == "float:left")
  aligned_unknown <- xml2::read_xml('<html xmlns="http://www.w3.org/1999/xhtml"><head/><body><img align="middle"/></body></html>')
  fails(sci_epub_xhtml_styles(list("align.xhtml" = aligned_unknown)), "Unsupported XHTML image alignment")
  hash <- unname(tools::md5sum(path))
  sci_repair_epub(path, fixture)
  check(identical(hash, unname(tools::md5sum(path))))
  table_path <- make_fixture("tables", tables = TRUE)
  table_result <- sci_repair_epub(table_path, fixture)
  check(table_result$table_header_ids == 2L)
  table_dir <- tempfile(tmpdir = fixture)
  dir.create(table_dir)
  sci_epub_extract(table_path, table_dir)
  table_xml <- xml2::read_xml(file.path(table_dir, "EPUB/text/a.xhtml"))
  check(identical(xml2::xml_attr(xml2::xml_find_all(table_xml, ".//*[local-name()='th']"), "id"),
                  c("epub-table-1-value", "epub-table-2-value")))
  check(identical(xml2::xml_attr(xml2::xml_find_all(table_xml, ".//*[@headers]"), "headers"),
                  c("epub-table-1-value", "epub-table-2-value")))
  check(xml2::xml_attr(xml2::xml_find_first(table_xml, ".//*[@aria-describedby]"), "aria-describedby") == "epub-table-1-value")
  check(xml2::xml_attr(xml2::xml_find_first(table_xml, ".//*[@aria-labelledby]"), "aria-labelledby") == "epub-table-2-value")
  check("#epub-table-1-value" %in% xml2::xml_attr(xml2::xml_find_all(table_xml, ".//*[@href]"), "href"))
  ambiguous_table <- make_fixture("ambiguous-table", tables = TRUE, ambiguous_table_link = TRUE)
  before_table <- unname(tools::md5sum(ambiguous_table))
  fails(sci_repair_epub(ambiguous_table, fixture), "Ambiguous link")
  check(identical(before_table, unname(tools::md5sum(ambiguous_table))))
  for (kind in c("missing", "ambiguous")) {
    broken <- make_fixture(kind, target = if (kind == "missing") "not-found" else "target", duplicate = kind == "ambiguous")
    before <- unname(tools::md5sum(broken))
    fails(sci_repair_epub(broken, fixture), "uniquely resolve")
    check(identical(before, unname(tools::md5sum(broken))))
  }
  # A changed stored mimetype byte makes the archive CRC/content invalid.
  corrupt <- file.path(fixture, "corrupt.epub")
  file.copy(path, corrupt)
  con <- file(corrupt, "r+b")
  seek(con, where = 38L, origin = "start")
  writeBin(charToRaw("X"), con)
  close(con)
  fails(sci_verify_epub(corrupt), "CRC|extract|unzip|mimetype")
  cat("EPUB packaging:", checks, "offline checks passed.\n")
}, finally = unlink(fixture, recursive = TRUE))
