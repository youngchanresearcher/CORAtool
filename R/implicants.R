## Prime implicant objects and their sufficiency statistics.

new_implicant <- function(ctx, implicant, raw_implicant, coverage,
                          essential = FALSE) {
  structure(
    list(
      ctx = ctx,
      implicant = if (essential) paste0("#", implicant) else implicant,
      label = implicant,
      raw_implicant = raw_implicant,
      coverage = as.integer(coverage),
      essential = essential
    ),
    class = "cora_implicant"
  )
}

new_implicant_mo <- function(ctx, implicant, raw_implicant, coverage, outputs) {
  structure(
    list(
      ctx = ctx,
      implicant = implicant,
      label = implicant,
      raw_implicant = raw_implicant,
      coverage = as.integer(coverage),
      outputs = as.integer(sort(outputs)),
      output_labels = ctx$output_labels[sort(outputs)]
    ),
    class = c("cora_implicant_mo", "cora_implicant")
  )
}

## Case-level input matrix, built once per context.
context_input_matrix <- function(ctx) {
  if (is.null(ctx$input_matrix)) {
    mat <- as.matrix(ctx$data[names(ctx$input_data)])
    storage.mode(mat) <- "integer"
    ctx$input_matrix <- mat
  }
  ctx$input_matrix
}

## Rows of the case-level data covered by a raw implicant.
implicant_hits <- function(ctx, raw_implicant) {
  in_cols <- names(ctx$input_data)
  if (length(in_cols) != length(raw_implicant)) {
    stopf("Size of input columns (%d) does not match implicant size (%d).",
          length(in_cols), length(raw_implicant))
  }
  mat <- context_input_matrix(ctx)
  hits <- rep(TRUE, nrow(mat))
  for (i in seq_along(raw_implicant)) {
    hits <- hits & (mat[, i] %in% raw_implicant[[i]])
  }
  hits
}

#' Sufficiency statistics of a prime implicant
#'
#' The coverage score is the share of the cases showing the outcome that the
#' prime implicant covers. The inclusion score is the share of the cases the
#' prime implicant covers that show the outcome.
#'
#' @param x A prime implicant, as returned by [cora_prime_implicants()].
#' @param ... Unused.
#'
#' @return A single number, or `NaN` when the denominator is empty.
#'
#' @examples
#' df <- data.frame(A = c(1, 0, 1, 0), B = c(1, 0, 0, 1),
#'                  C = c(0, 1, 1, 0), OUT = c(1, 1, 0, 1))
#' pis <- cora_prime_implicants(cora_context(df, "OUT"))
#' cora_coverage_score(pis[[1]])
#' cora_inclusion_score(pis[[1]])
#' @export
cora_coverage_score <- function(x, ...) UseMethod("cora_coverage_score")

#' @rdname cora_coverage_score
#' @export
cora_inclusion_score <- function(x, ...) UseMethod("cora_inclusion_score")

#' @export
cora_coverage_score.cora_implicant <- function(x, ...) {
  ctx <- x$ctx
  out_col <- ctx$output_labels[[1L]]
  hits <- implicant_hits(ctx, x$raw_implicant)
  positive <- ctx$data[[out_col]] == 1L
  mean(as.numeric(hits[positive]))
}

#' @export
cora_inclusion_score.cora_implicant <- function(x, ...) {
  ctx <- x$ctx
  out_col <- ctx$output_labels[[1L]]
  hits <- implicant_hits(ctx, x$raw_implicant)
  positive <- ctx$data[[out_col]] == 1L
  sum(hits & positive) / sum(hits)
}

#' @export
cora_coverage_score.cora_implicant_mo <- function(x, ...) {
  ctx <- x$ctx
  hits <- implicant_hits(ctx, x$raw_implicant)
  mask <- rep(TRUE, nrow(ctx$data))
  for (out in x$output_labels) mask <- mask & (ctx$data[[out]] == 1L)
  mean(as.numeric(hits[mask]))
}

#' @export
cora_inclusion_score.cora_implicant_mo <- function(x, ...) {
  ctx <- x$ctx
  hits <- implicant_hits(ctx, x$raw_implicant)
  mask <- rep(TRUE, nrow(ctx$data))
  for (out in x$output_labels) mask <- mask & (ctx$data[[out]] == 1L)
  sum(hits & mask) / sum(hits)
}

#' @export
format.cora_implicant <- function(x, ...) x$implicant

#' @export
print.cora_implicant <- function(x, ...) {
  cat(format(x), "\n", sep = "")
  invisible(x)
}

#' @export
format.cora_implicant_mo <- function(x, ...) {
  sprintf("%s [%s]", x$implicant, paste(x$outputs, collapse = ", "))
}

#' @export
print.cora_implicant_mo <- function(x, ...) {
  cat(format(x), "\n", sep = "")
  invisible(x)
}

#' @export
format.cora_implicants <- function(x, ...) {
  if (length(x) == 0L) return("<no prime implicants>")
  paste(vapply(x, format, character(1)), collapse = ", ")
}

#' @export
print.cora_implicants <- function(x, ...) {
  cat(format(x), "\n", sep = "")
  invisible(x)
}
