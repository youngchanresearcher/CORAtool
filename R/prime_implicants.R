#' Prime implicants of an optimisation context
#'
#' Minimises the truth table with the algorithm chosen in the context and
#' returns the resulting prime implicants.
#'
#' @param ctx A [cora_context()].
#'
#' @return A list of prime implicants, of class `cora_implicants`. Every
#'   literal is printed as `CONDITION{value}`, a term joins its literals with
#'   `*`, and an essential prime implicant is prefixed with `#`.
#'
#' @examples
#' df <- data.frame(A = c(1, 0, 1, 0), B = c(1, 0, 0, 1),
#'                  C = c(0, 1, 1, 0), OUT = c(1, 1, 0, 1))
#' cora_prime_implicants(cora_context(df, "OUT"))
#' @export
cora_prime_implicants <- function(ctx) {
  stopifnot(inherits(ctx, "cora_context"))
  if (!is.null(ctx$prime_implicants)) return(ctx$prime_implicants)
  pis <- switch(
    ctx$algorithm,
    "ON-DC" = prime_implicants_on_dc(ctx),
    "ON-OFF" = prime_implicants_on_off(ctx),
    stopf("Unknown algorithm \"%s\".", ctx$algorithm)
  )
  class(pis) <- "cora_implicants"
  ctx$prime_implicants <- pis
  pis
}

#' Prime implicant chart
#'
#' @param ctx A [cora_context()].
#'
#' @return A data frame with one row per prime implicant and one column per
#'   covered truth table row; an entry is 1 when the prime implicant covers
#'   that row and 0 otherwise.
#'
#' @examples
#' df <- data.frame(A = c(1, 0, 1, 0), B = c(1, 0, 0, 1),
#'                  C = c(0, 1, 1, 0), OUT = c(1, 1, 0, 1))
#' cora_pi_chart(cora_context(df, "OUT"))
#' @export
cora_pi_chart <- function(ctx) {
  stopifnot(inherits(ctx, "cora_context"))
  if (!is.null(ctx$pi_chart)) return(ctx$pi_chart)
  pis <- cora_prime_implicants(ctx)
  if (length(pis) == 0L) return(data.frame())
  cares <- sort(unique(unlist(lapply(pis, function(p) p$coverage),
                              use.names = FALSE)))
  mat <- matrix(0L, nrow = length(pis), ncol = length(cares),
                dimnames = list(
                  if (ctx$multi_output) {
                    vapply(pis, function(p) {
                      sprintf("%s, [%s]", p$implicant,
                              paste(p$outputs, collapse = ", "))
                    }, character(1))
                  } else {
                    vapply(pis, function(p) p$implicant, character(1))
                  },
                  as.character(cares)
                ))
  for (i in seq_along(pis)) {
    mat[i, match(pis[[i]]$coverage, cares)] <- 1L
  }
  chart <- as.data.frame(mat, check.names = FALSE)
  if (!ctx$multi_output) ctx$pi_chart <- chart
  chart
}
