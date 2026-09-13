## Optional cross-check against the original Python implementation. Nothing
## in the package needs Python; these helpers exist so that a result can be
## verified against the reference implementation when it is installed.

#' Is the Python CORA package reachable?
#'
#' @return `TRUE` when both 'reticulate' and the Python `cora` module are
#'   available, `FALSE` otherwise.
#'
#' @examples
#' cora_python_available()
#' @export
cora_python_available <- function() {
  if (!requireNamespace("reticulate", quietly = TRUE)) return(FALSE)
  isTRUE(tryCatch(reticulate::py_module_available("cora"),
                  error = function(e) FALSE))
}

python_cora <- function() {
  if (!cora_python_available()) {
    stopf(paste0("The Python 'cora' package is not available. Install ",
                 "'reticulate' and the Python package, or use the R ",
                 "implementation, which needs neither."))
  }
  reticulate::import("cora", delay_load = FALSE)
}

## Summary of a result set that can be compared across implementations.
summarise_result <- function(implicants, solutions, multi_output) {
  pis <- sort(vapply(implicants, function(p) {
    if (multi_output) {
      paste0(p$implicant, "|", paste(sort(p$outputs), collapse = ","))
    } else {
      p$implicant
    }
  }, character(1)))
  sols <- sort(vapply(solutions, function(s) {
    if (multi_output) {
      paste(vapply(s$system_multiple, function(per_out) {
        paste(sort(vapply(per_out, function(i) i$implicant, character(1))),
              collapse = "+")
      }, character(1)), collapse = " / ")
    } else {
      paste(sort(vapply(s$system, function(i) i$implicant, character(1))),
            collapse = "+")
    }
  }, character(1)))
  list(prime_implicants = pis, solutions = sols)
}

#' Cross-check a result against the Python implementation
#'
#' Runs the same analysis through the original Python `cora` package and
#' compares the prime implicants and the irredundant solutions. Results are
#' compared as sets: the two implementations enumerate solutions in different
#' orders, so the running numbers of the solutions need not line up.
#'
#' @param ctx A [cora_context()].
#'
#' @return A list with the two summaries and a logical `agrees` flag,
#'   invisibly returned alongside a printed report.
#'
#' @examples
#' df <- data.frame(A = c(1, 0, 1, 0), B = c(1, 0, 0, 1),
#'                  C = c(0, 1, 1, 0), OUT = c(1, 1, 0, 1))
#' if (cora_python_available()) {
#'   cora_compare_python(cora_context(df, "OUT"))
#' }
#' @export
cora_compare_python <- function(ctx) {
  stopifnot(inherits(ctx, "cora_context"))
  py <- python_cora()

  r_side <- summarise_result(
    cora_prime_implicants(ctx),
    if (ctx$multi_output) cora_irredundant_systems(ctx)
    else cora_irredundant_sums(ctx),
    ctx$multi_output
  )

  args <- list(data = ctx$data, output_labels = as.list(ctx$output_labels),
               algorithm = ctx$algorithm, n_cut = ctx$n_cut,
               inc_score1 = ctx$inc_score1)
  if (!is.null(ctx$inc_score2)) args$inc_score2 <- ctx$inc_score2
  if (!is.null(ctx$U)) args$U <- ctx$U
  if (!is.null(ctx$input_labels)) args$input_labels <- as.list(ctx$input_labels)
  py_ctx <- do.call(py$OptimizationContext, args)

  py_pis <- py_ctx$get_prime_implicants()
  py_sols <- if (ctx$multi_output) py_ctx$get_irredundant_systems()
             else py_ctx$get_irredundant_sums()
  py_side <- list(
    prime_implicants = sort(vapply(py_pis, function(p) {
      if (ctx$multi_output) {
        paste0(as.character(p$implicant), "|",
               paste(sort(as.integer(unlist(p$outputs))), collapse = ","))
      } else {
        as.character(p$implicant)
      }
    }, character(1))),
    solutions = sort(vapply(py_sols, function(s) {
      if (ctx$multi_output) {
        paste(vapply(s$system_multiple, function(per_out) {
          paste(sort(vapply(per_out, function(i) as.character(i$implicant),
                            character(1))), collapse = "+")
        }, character(1)), collapse = " / ")
      } else {
        paste(sort(vapply(s$system, function(i) as.character(i$implicant),
                          character(1))), collapse = "+")
      }
    }, character(1)))
  )

  agrees <- identical(r_side$prime_implicants, py_side$prime_implicants) &&
    identical(r_side$solutions, py_side$solutions)

  cat(sprintf("prime implicants: %s\n",
              if (identical(r_side$prime_implicants,
                            py_side$prime_implicants)) "agree" else "DIFFER"))
  cat(sprintf("solutions       : %s\n",
              if (identical(r_side$solutions, py_side$solutions)) "agree"
              else "DIFFER"))
  invisible(list(r = r_side, python = py_side, agrees = agrees))
}
