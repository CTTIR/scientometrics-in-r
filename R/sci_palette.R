#' Scientometrics in R colour palette
#'
#' Returns `n` colours from the colour-blind-friendly 'viridis' palette
#' (option `"D"`) used for the book's figures.
#'
#' @param n Number of colours to return.
#' @return A character vector of hex colour codes.
#' @export
#' @examples
#' palette_sci(4)
palette_sci <- function(n = 6) {
  viridis::viridis(n, option = "D")
}

#' Minimal ggplot2 theme for the book
#'
#' @param base_size Base font size (default 11).
#' @param base_family Font family. Defaults to the PDF rendering font when set,
#'   otherwise the graphics device's default family.
#' @return A ggplot2 theme object.
#' @export
#' @examples
#' library(ggplot2)
#' ggplot(mtcars, aes(wt, mpg)) +
#'   geom_point() +
#'   theme_sci()
theme_sci <- function(base_size = 11, base_family = getOption("sci.pdf_family", "")) {
  ggplot2::theme_minimal(base_size = base_size, base_family = base_family) +
    ggplot2::theme(
      plot.title = ggplot2::element_text(face = "bold"),
      strip.text = ggplot2::element_text(face = "bold"),
      legend.position = "bottom"
    )
}
