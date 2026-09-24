## Optional cross-check against the original Python implementation. Nothing
## in the package needs Python; these helpers exist so that a result can be
## verified against the reference implementation when it is installed.

#' Is the Python CORA package reachable?
#'
#' Answering the question means asking 'reticulate' for a module, which starts
#' Python. On a machine where no interpreter has been configured, recent
#' versions of 'reticulate' provision one at that moment, which can take half a
#' minute and reach the network. The example is therefore not run
#' automatically; call it yourself when you want the answer.
#'
#' @return `TRUE` when both 'reticulate' and the Python `cora` module are
#'   available, `FALSE` otherwise.
#'
#' @examples
#' \dontrun{
#' cora_python_available()
#' }
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
#' @return An object of class `cora_comparison`: a list holding the two
#'   summaries (`r`, `python`), a logical `agrees`, and for each of
#'   `prime_implicants` and `solutions` a list of `agree`, `r_only` and
#'   `python_only`. Nothing is written to the console while it is computed;
#'   printing the object gives a short report of what agrees and what does
#'   not.
#'
#' @examples
#' \dontrun{
#' ## Needs a Python installation carrying the original `cora` package, so it
#' ## is not run automatically. See `cora_python_available()`.
#' df <- data.frame(A = c(1, 0, 1, 0), B = c(1, 0, 0, 1),
#'                  C = c(0, 1, 1, 0), OUT = c(1, 1, 0, 1))
#' if (cora_python_available()) {
#'   cora_compare_python(cora_context(df, "OUT"))
#' }
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

  pis <- compare_sets(r_side$prime_implicants, py_side$prime_implicants)
  sols <- compare_sets(r_side$solutions, py_side$solutions)
  structure(
    list(r = r_side, python = py_side, agrees = pis$agree && sols$agree,
         prime_implicants = pis, solutions = sols),
    class = "cora_comparison"
  )
}

## What two sorted character vectors have in common and where they part.
compare_sets <- function(r, python) {
  list(agree = identical(r, python),
       r_only = setdiff(r, python),
       python_only = setdiff(python, r))
}

#' @export
format.cora_comparison <- function(x, ...) {
  part <- function(name, cmp) {
    if (cmp$agree) return(sprintf("%-17s: agree", name))
    c(sprintf("%-17s: DIFFER", name),
      if (length(cmp$r_only))
        sprintf("  only in R      : %s", paste(cmp$r_only, collapse = ", ")),
      if (length(cmp$python_only))
        sprintf("  only in Python : %s", paste(cmp$python_only, collapse = ", ")))
  }
  c("<cora_comparison>",
    part("prime implicants", x$prime_implicants),
    part("solutions", x$solutions))
}

#' @export
print.cora_comparison <- function(x, ...) {
  writeLines(format(x))
  invisible(x)
}
