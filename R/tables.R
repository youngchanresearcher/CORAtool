## Summary tables over prime implicants and solutions.

#' Statistical overview of the prime implicants
#'
#' @param ctx A [cora_context()].
#'
#' @return A data frame with one row per prime implicant holding its coverage
#'   score (`Cov.r`), its inclusion score (`Inc.`) and, for every solution,
#'   the share of the outcome that the prime implicant covers uniquely within
#'   that solution. `NA` marks a prime implicant absent from a solution.
#'
#' @examples
#' df <- data.frame(A = c(1, 0, 1, 0), B = c(1, 0, 0, 1),
#'                  C = c(0, 1, 1, 0), OUT = c(1, 1, 0, 1))
#' cora_pi_details(cora_context(df, "OUT"))
#' @export
cora_pi_details <- function(ctx) {
  stopifnot(inherits(ctx, "cora_context"))
  if (!is.null(ctx$details)) return(ctx$details)
  pis <- cora_prime_implicants(ctx)

  out <- data.frame(
    PI = vapply(pis, function(p) p$implicant, character(1)),
    Cov.r = vapply(pis, function(p) py_round(cora_coverage_score(p), 2),
                   numeric(1)),
    Inc. = vapply(pis, function(p) py_round(cora_inclusion_score(p), 2),
                  numeric(1)),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )

  if (!ctx$multi_output) {
    solutions <- cora_irredundant_sums(ctx)
    prefix <- "M"
    per_solution <- lapply(solutions, system_implicant_coverage)
  } else {
    solutions <- cora_irredundant_systems(ctx)
    prefix <- "S"
    per_solution <- lapply(solutions, system_multi_implicant_coverage,
                           strict = FALSE)
  }

  for (k in seq_along(solutions)) {
    scores <- per_solution[[k]]
    out[[paste0(prefix, solutions[[k]]$index)]] <- vapply(
      out$PI,
      function(p) if (p %in% names(scores)) py_round(scores[[p]], 2) else NA_real_,
      numeric(1), USE.NAMES = FALSE
    )
  }
  ctx$details <- out
  out
}

#' Statistical overview of a solution
#'
#' @param ctx A [cora_context()].
#'
#' @return A one-row data frame with the coverage and inclusion score of the
#'   first irredundant solution.
#'
#' @examples
#' df <- data.frame(A = c(1, 0, 1, 0), B = c(1, 0, 0, 1),
#'                  C = c(0, 1, 1, 0), OUT = c(1, 1, 0, 1))
#' cora_system_details(cora_context(df, "OUT"))
#' @export
cora_system_details <- function(ctx) {
  stopifnot(inherits(ctx, "cora_context"))
  if (!is.null(ctx$sol_details)) return(ctx$sol_details)
  solutions <- if (ctx$multi_output) cora_irredundant_systems(ctx)
               else cora_irredundant_sums(ctx)
  if (length(solutions) == 0L) stopf("No irredundant solution was found.")
  s <- solutions[[1L]]
  out <- data.frame(
    Cov. = py_round(cora_coverage_score(s), 2),
    Inc. = py_round(cora_inclusion_score(s), 2),
    row.names = "Solution details",
    check.names = FALSE
  )
  ctx$sol_details <- out
  out
}

#' Solution summary table
#'
#' @param ctx A [cora_context()].
#'
#' @return A data frame with one column per prime implicant marking, with a 1,
#'   the solutions the prime implicant belongs to. In the multi-outcome case
#'   each system contributes one row per outcome, and the `Output` and
#'   `System` columns identify them.
#'
#' @examples
#' df <- data.frame(A = c(1, 0, 1, 0), B = c(1, 0, 0, 1),
#'                  C = c(0, 1, 1, 0), OUT = c(1, 1, 0, 1))
#' cora_solutions(cora_context(df, "OUT"))
#' @export
cora_solutions <- function(ctx) {
  stopifnot(inherits(ctx, "cora_context"))
  pis <- cora_prime_implicants(ctx)
  pi_names <- vapply(pis, function(p) p$implicant, character(1))

  if (!ctx$multi_output) {
    solutions <- cora_irredundant_sums(ctx)
    mat <- matrix(0L, nrow = length(solutions), ncol = length(pis),
                  dimnames = list(NULL, pi_names))
    for (r in seq_along(solutions)) {
      in_sol <- vapply(solutions[[r]]$system, function(i) i$implicant,
                       character(1))
      mat[r, pi_names %in% in_sol] <- 1L
    }
    out <- as.data.frame(mat, check.names = FALSE)
    ctx$solution_dataframe <- out
    return(out)
  }

  solutions <- cora_irredundant_systems(ctx)
  n_out <- length(ctx$output_labels)
  mat <- matrix(0L, nrow = length(solutions) * n_out, ncol = length(pis),
                dimnames = list(NULL, pi_names))
  for (i in seq_along(solutions)) {
    for (j in seq_len(n_out)) {
      in_sol <- vapply(solutions[[i]]$system_multiple[[j]],
                       function(k) k$implicant, character(1))
      mat[n_out * (i - 1L) + j, pi_names %in% in_sol] <- 1L
    }
  }
  out <- as.data.frame(mat, check.names = FALSE)
  out[["Output"]] <- rep(ctx$output_labels_final, times = length(solutions))
  out[["System"]] <- rep(as.character(seq_along(solutions)), each = n_out)
  ctx$solution_dataframe <- out
  out
}

#' Descriptive rendering of a solution
#'
#' Renders a solution as a sufficiency, necessity or equivalence statement,
#' depending on whether its inclusion and coverage scores clear the
#' thresholds of the analysis.
#'
#' @param x A solution from [cora_irredundant_sums()] or
#'   [cora_irredundant_systems()].
#' @param cov Minimum coverage score for the relation to be read as
#'   necessary as well as sufficient.
#' @param ... Unused.
#'
#' @return A character string.
#'
#' @examples
#' df <- data.frame(A = c(1, 0, 1, 0), B = c(1, 0, 0, 1),
#'                  C = c(0, 1, 1, 0), OUT = c(1, 1, 0, 1))
#' sums <- cora_irredundant_sums(cora_context(df, "OUT"))
#' cora_describe(sums[[1]])
#' @export
cora_describe <- function(x, cov = 1, ...) UseMethod("cora_describe")

final_inc_score <- function(ctx) {
  if (!is.null(ctx$inc_score2) && !is.null(ctx$U) && ctx$U == 0) {
    ctx$inc_score2
  } else {
    ctx$inc_score1
  }
}

#' @export
cora_describe.cora_system <- function(x, cov = 1, ...) {
  ctx <- x$ctx
  solution_cov <- cora_coverage_score(x)
  solution_inc <- cora_inclusion_score(x)
  threshold <- final_inc_score(ctx)
  body <- paste(vapply(x$system, function(i) i$implicant, character(1)),
                collapse = " + ")
  if (solution_cov >= cov && solution_cov >= 0.5 &&
      solution_inc >= 0.5 && solution_inc >= threshold) {
    sprintf("%s <=> %s", body, x$output)
  } else if (solution_cov >= cov && solution_cov >= 0.5) {
    sprintf("%s <= %s", body, x$output)
  } else if (solution_inc >= threshold && solution_inc >= 0.5) {
    sprintf("%s => %s", body, x$output)
  } else {
    "Warning!"
  }
}

#' @export
cora_describe.cora_system_multi <- function(x, cov = 1, ...) {
  ctx <- x$ctx
  threshold <- final_inc_score(ctx)
  solution_cov <- cora_coverage_score(x)
  solution_inc <- cora_inclusion_score(x)
  lines <- sprintf("---- System %d ----", x$index)
  for (j in seq_along(x$system_multiple)) {
    system <- x$system_multiple[[j]]
    labs <- vapply(system, function(i) i$implicant, character(1))
    if (any(labs == "1")) {
      lines <- c(lines, sprintf("1 <=> %s", x$output_labels[[j]]))
    } else if (length(labs) == 0L) {
      lines <- c(lines, sprintf("0 <=> %s", x$output_labels[[j]]))
    } else {
      body <- paste(labs, collapse = " + ")
      if (solution_inc >= threshold && solution_inc >= 0.5 &&
          solution_cov >= cov && solution_cov >= 0.5) {
        lines <- c(lines, sprintf("%s <=> %s", body, x$output_labels[[j]]))
      } else if (solution_inc >= threshold && solution_inc >= 0.5) {
        lines <- c(lines, sprintf("%s => %s", body, x$output_labels[[j]]))
      } else if (solution_cov >= cov && solution_cov >= 0.5) {
        lines <- c(lines, sprintf("%s <= %s", body, x$output_labels[[j]]))
      } else {
        lines <- c(lines, "Warning!")
      }
    }
  }
  paste(lines, collapse = "\n")
}

#' @export
print.cora_context <- function(x, ...) {
  cat("<cora_context>\n")
  cat(sprintf("  cases          : %d\n", nrow(x$data)))
  cat(sprintf("  inputs         : %s\n",
              paste(if (is.null(x$input_labels)) "<pending>" else x$input_labels,
                    collapse = ", ")))
  cat(sprintf("  outcomes       : %s\n", paste(x$output_labels, collapse = ", ")))
  cat(sprintf("  algorithm      : %s\n", x$algorithm))
  cat(sprintf("  n_cut          : %s\n", format(x$n_cut)))
  cat(sprintf("  inc_score1     : %s\n", format(x$inc_score1)))
  if (!is.null(x$inc_score2)) {
    cat(sprintf("  inc_score2     : %s (U = %s)\n",
                format(x$inc_score2), format(x$U)))
  }
  invisible(x)
}
