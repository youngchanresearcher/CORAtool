#' Configurational data mining
#'
#' Analyses every n-tuple of input variables in search of tuples that
#' generate a solution, which amounts to a configurational version of
#' Occam's razor: it keeps the number of inputs required for a solution at a
#' minimum.
#'
#' @param data A data frame.
#' @param output_labels Character vector naming the outcome columns, in the
#'   notation accepted by [cora_context()].
#' @param len_of_tuple Number of input variables to combine.
#' @param input_labels Character vector naming the input columns to draw
#'   from. Defaults to every column that is neither an outcome nor the case
#'   column.
#' @param case_col Name of the column holding case identifiers, or `NULL`.
#' @param n_cut Minimum number of cases below which a truth table row is
#'   declared a don't care.
#' @param inc_score1 Minimum sufficiency inclusion score for an output
#'   function value of 1.
#' @param inc_score2 Maximum sufficiency inclusion score for an output
#'   function value of 0, or `NULL`.
#' @param U Either 0 or 1; required when `inc_score2` is given.
#' @param algorithm `"ON-DC"` or `"ON-OFF"`.
#' @param automatic If `TRUE`, the search widens the tuple length until a
#'   non-zero solution is found.
#'
#' @return A data frame with one row per tuple, holding the number of
#'   irredundant solutions and the best inclusion, coverage and combined
#'   score across them.
#'
#' @examples
#' data <- data.frame(A = c(1, 1, 1, 0), B = c(0, 1, 0, 1),
#'                    C = c(1, 1, 0, 0), O = c(0, 1, 0, 1))
#' cora_data_mining(data, "O", len_of_tuple = 2)
#' @export
cora_data_mining <- function(data,
                             output_labels,
                             len_of_tuple,
                             input_labels = NULL,
                             case_col = NULL,
                             n_cut = 1,
                             inc_score1 = 1,
                             inc_score2 = NULL,
                             U = NULL,
                             algorithm = c("ON-DC", "ON-OFF"),
                             automatic = FALSE) {
  algorithm <- match.arg(algorithm)
  plain_outputs <- sub(OUTPUT_PATTERN, "\\1", output_labels)
  if (is.null(input_labels)) {
    input_labels <- setdiff(names(data), c(plain_outputs, case_col))
  }
  if (len_of_tuple < 1L || len_of_tuple > length(input_labels)) {
    stopf("`len_of_tuple` must lie between 1 and %d.", length(input_labels))
  }

  combos <- utils::combn(input_labels, len_of_tuple, simplify = FALSE)
  rows <- lapply(combos, function(cols) {
    ctx <- cora_context(data, output_labels, input_labels = cols,
                        case_col = case_col, n_cut = n_cut,
                        inc_score1 = inc_score1, inc_score2 = inc_score2,
                        U = U, algorithm = algorithm)
    solutions <- tryCatch(
      if (length(output_labels) == 1L) cora_irredundant_sums(ctx)
      else cora_irredundant_systems(ctx),
      error = function(e) structure(list(), class = "cora_systems")
    )
    if (length(solutions) == 0L) {
      return(list(combination = paste(cols, collapse = ", "), n = 0L,
                  inc = 0, cov = 0, score = 0))
    }
    inc <- vapply(solutions, cora_inclusion_score, numeric(1))
    cov <- vapply(solutions, cora_coverage_score, numeric(1))

    ## A tautological single-outcome solution carries no information.
    tautology <- length(output_labels) == 1L && length(solutions) == 1L &&
      length(solutions[[1L]]$system) > 0L &&
      sub("^#", "", solutions[[1L]]$system[[1L]]$implicant) == "1"
    if (tautology) {
      return(list(combination = paste(cols, collapse = ", "), n = 0L,
                  inc = 0, cov = 0, score = 0))
    }
    list(combination = paste(cols, collapse = ", "),
         n = length(solutions),
         inc = py_round(max(inc), 3),
         cov = py_round(max(cov), 3),
         score = py_round(max(inc * cov), 3))
  })

  result <- data.frame(
    Combination = vapply(rows, function(r) r$combination, character(1)),
    Nr_of_systems = vapply(rows, function(r) as.integer(r$n), integer(1)),
    Inc_score = vapply(rows, function(r) r$inc, numeric(1)),
    Cov_score = vapply(rows, function(r) r$cov, numeric(1)),
    Score = vapply(rows, function(r) r$score, numeric(1)),
    stringsAsFactors = FALSE
  )

  if (!automatic || sum(result$Nr_of_systems) != 0L ||
      len_of_tuple >= length(input_labels)) {
    return(result)
  }
  cora_data_mining(data, output_labels, len_of_tuple + 1L, input_labels,
                   case_col, n_cut, inc_score1, inc_score2, U, algorithm,
                   automatic)
}
