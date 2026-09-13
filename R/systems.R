## Irredundant solutions: single-outcome sums and multi-outcome systems.

new_irredundant_system <- function(ctx, system, index) {
  if (length(ctx$output_labels) == 1L && length(system) > 0L) {
    ess <- vapply(system, function(i) isTRUE(i$essential), logical(1))
    system <- system[order(!ess)]
  }
  structure(
    list(ctx = ctx, system = system, index = index,
         output = ctx$output_labels_final[[1L]]),
    class = "cora_system"
  )
}

new_irredundant_system_multi <- function(ctx, system_multiple, index) {
  structure(
    list(ctx = ctx, system_multiple = system_multiple, index = index,
         output_labels = ctx$output_labels_final),
    class = "cora_system_multi"
  )
}

## Rows of the case-level data covered by at least one implicant of a system.
system_hits <- function(ctx, implicants) {
  hits <- rep(FALSE, nrow(ctx$data))
  for (i in implicants) hits <- hits | implicant_hits(ctx, i$raw_implicant)
  hits
}

#' @export
cora_coverage_score.cora_system <- function(x, ...) {
  ctx <- x$ctx
  out_col <- ctx$output_labels[[1L]]
  positive <- ctx$data[[out_col]] == 1L
  mean(as.numeric(system_hits(ctx, x$system)[positive]))
}

#' @export
cora_inclusion_score.cora_system <- function(x, ...) {
  ctx <- x$ctx
  out_col <- ctx$output_labels[[1L]]
  hits <- system_hits(ctx, x$system)
  mean(as.numeric(ctx$data[[out_col]][hits]))
}

#' @export
cora_coverage_score.cora_system_multi <- function(x, ...) {
  ctx <- x$ctx
  out_mat <- as.matrix(ctx$data[ctx$output_labels])
  any_positive <- apply(out_mat == 1L, 1L, any)
  hits <- system_hits(ctx, system_unique_implicants(x))
  mean(as.numeric(hits[any_positive]))
}

#' @export
cora_inclusion_score.cora_system_multi <- function(x, ...) {
  ctx <- x$ctx
  out_mat <- as.matrix(ctx$data[ctx$output_labels])
  new_output <- as.integer(apply(out_mat, 1L, sum) > 0L)
  hits <- system_hits(ctx, system_unique_implicants(x))
  mean(new_output[hits])
}

system_unique_implicants <- function(x) {
  all_impl <- unlist(x$system_multiple, recursive = FALSE, use.names = FALSE)
  if (length(all_impl) == 0L) return(list())
  keys <- vapply(all_impl, function(i) {
    paste0(i$implicant, "#", int_key(i$outputs))
  }, character(1))
  all_impl[!duplicated(keys)]
}

## Share of the outcome that each implicant of a sum covers on its own.
system_implicant_coverage <- function(x) {
  ctx <- x$ctx
  out_col <- ctx$output_labels[[1L]]
  positive <- which(ctx$data[[out_col]] == 1L)
  if (length(positive) == 0L) return(stats::setNames(numeric(0), character(0)))
  covered <- lapply(x$system, function(i) {
    positive[implicant_hits(ctx, i$raw_implicant)[positive]]
  })
  counts <- table(unlist(covered, use.names = FALSE))
  vals <- vapply(covered, function(cv) {
    if (length(cv) == 0L) return(0)
    unique_rows <- cv[counts[as.character(cv)] == 1L]
    length(unique_rows) / length(positive)
  }, numeric(1))
  stats::setNames(vals, vapply(x$system, function(i) i$implicant, character(1)))
}

## Multi-outcome analogue: coverage unique to an implicant among the cases
## showing the outcome combination the implicant refers to.
system_multi_implicant_coverage <- function(x, strict) {
  ctx <- x$ctx
  implicants <- system_unique_implicants(x)
  if (length(implicants) == 0L) {
    return(stats::setNames(numeric(0), character(0)))
  }
  ## Implicants whose outcome set contains this implicant's outcome set.
  supersets <- lapply(implicants, function(i1) {
    Filter(function(i2) {
      !identical(i2$implicant, i1$implicant) &&
        all(i1$outputs %in% i2$outputs)
    }, implicants)
  })

  out_cols <- ctx$output_labels
  vals <- vapply(seq_along(implicants), function(k) {
    impl <- implicants[[k]]
    mask <- rep(TRUE, nrow(ctx$data))
    for (idx in seq_along(out_cols)) {
      if (idx %in% impl$outputs) {
        mask <- mask & (ctx$data[[out_cols[[idx]]]] == 1L)
      } else if (strict) {
        mask <- mask & (ctx$data[[out_cols[[idx]]]] == 0L)
      }
    }
    denom <- sum(mask)
    if (denom == 0L) return(NaN)
    s_in <- which(mask & implicant_hits(ctx, impl$raw_implicant))
    s_out <- integer(0)
    for (other in supersets[[k]]) {
      s_out <- c(s_out, which(mask & implicant_hits(ctx, other$raw_implicant)))
    }
    length(setdiff(s_in, s_out)) / denom
  }, numeric(1))
  stats::setNames(vals, vapply(implicants, function(i) i$implicant, character(1)))
}

#' @export
format.cora_system <- function(x, ...) {
  sprintf("M%d: %s", x$index,
          paste(vapply(x$system, function(i) i$implicant, character(1)),
                collapse = " + "))
}

#' @export
print.cora_system <- function(x, ...) {
  cat(format(x), "\n", sep = "")
  invisible(x)
}

#' @export
format.cora_system_multi <- function(x, ...) {
  lines <- sprintf("---- System %d ----", x$index)
  for (j in seq_along(x$system_multiple)) {
    system <- x$system_multiple[[j]]
    labs <- vapply(system, function(i) i$implicant, character(1))
    body <- if (any(labs == "1")) "1" else if (length(labs) == 0L) "0" else
      paste(labs, collapse = " + ")
    lines <- c(lines, sprintf("%s: %s", x$output_labels[[j]], body))
  }
  paste(lines, collapse = "\n")
}

#' @export
print.cora_system_multi <- function(x, ...) {
  cat(format(x), "\n", sep = "")
  invisible(x)
}

#' @export
print.cora_systems <- function(x, ...) {
  if (length(x) == 0L) {
    cat("<no irredundant solutions>\n")
    return(invisible(x))
  }
  for (s in x) cat(format(s), "\n", sep = "")
  invisible(x)
}

#' Irredundant sums of a single-outcome analysis
#'
#' Solves the prime implicant chart with Petrick's method and returns every
#' irredundant sum of prime implicants.
#'
#' @param ctx A [cora_context()] with exactly one outcome.
#' @param max_depth Optional upper bound on the number of prime implicants a
#'   solution may contain. Solutions keep the number they have in the
#'   unrestricted set, so a restricted call can return `M2` and `M5`; the
#'   restriction applies to the call, never to the context, so the next call
#'   without `max_depth` still sees every solution.
#'
#' @return A list of solutions, of class `cora_systems`.
#'
#' @note The number of irredundant sums can grow exponentially with the size
#'   of the prime implicant chart.
#'
#' @examples
#' df <- data.frame(A = c(1, 0, 1, 0), B = c(1, 0, 0, 1),
#'                  C = c(0, 1, 1, 0), OUT = c(1, 1, 0, 1))
#' cora_irredundant_sums(cora_context(df, "OUT"))
#'
#' ## Only the solutions built from at most one prime implicant.
#' cora_irredundant_sums(cora_context(df, "OUT"), max_depth = 1)
#' @export
cora_irredundant_sums <- function(ctx, max_depth = NULL) {
  stopifnot(inherits(ctx, "cora_context"))
  if (ctx$multi_output) {
    stopf(paste0("Irredundant sums are not supported in multi-output mode. ",
                 "Use cora_irredundant_systems()."))
  }
  ## What is cached is the unrestricted set. A max_depth call filters a copy
  ## on the way out, so it neither reads a filtered list as if it were the
  ## whole set nor leaves one behind for cora_pi_details() and friends.
  if (is.null(ctx$irredundant_sums)) {
    pis <- cora_prime_implicants(ctx)
    sums <- if (length(pis) == 0L) list()
            else cora_petrick(lapply(pis, function(p) p$coverage))$sums
    all_sums <- lapply(seq_along(sums), function(i) {
      new_irredundant_system(ctx, pis[sums[[i]]], i)
    })
    class(all_sums) <- "cora_systems"
    ctx$irredundant_sums <- all_sums
  }
  out <- ctx$irredundant_sums
  if (is.null(max_depth)) return(out)
  max_depth <- check_count(max_depth, "max_depth")
  keep <- vapply(out, function(s) length(s$system) <= max_depth, logical(1))
  structure(out[keep], class = "cora_systems")
}

#' Irredundant systems of a multi-outcome analysis
#'
#' Solves the prime implicant chart of every outcome and combines the
#' single-outcome solutions into irredundant systems. Individual functions
#' inside a system need not be irredundant, but the system as a whole is.
#'
#' @param ctx A [cora_context()] with more than one outcome.
#'
#' @return A list of systems, of class `cora_systems`.
#'
#' @examples
#' df <- data.frame(A = c(1, 1, 0, 0), B = c(2, 1, 2, 2), C = c(0, 1, 1, 2),
#'                  D = c(1, 0, 0, 0), OUT1 = c(1, 2, 0, 1),
#'                  OUT2 = c(2, 0, 1, 1), OUT3 = c(1, 0, 2, 1))
#' ## B is coded 1 and 2 here, which CORA does not accept.
#' df <- cora_recode(df, "B")
#' ctx <- cora_context(df, c("OUT1{1,2}", "OUT2{1}", "OUT3{1,0}"),
#'                     algorithm = "ON-OFF")
#' cora_irredundant_systems(ctx)
#' @export
cora_irredundant_systems <- function(ctx) {
  stopifnot(inherits(ctx, "cora_context"))
  if (!is.null(ctx$irredundant_systems)) return(ctx$irredundant_systems)
  if (!ctx$multi_output) {
    stopf(paste0("Irredundant systems are not supported in single-output ",
                 "mode. Use cora_irredundant_sums()."))
  }
  pis <- cora_prime_implicants(ctx)
  n_out <- length(ctx$output_labels)

  ## Solve each outcome separately, then multiply the solution spaces out.
  per_output <- list()
  for (j in seq_len(n_out)) {
    idx <- which(vapply(pis, function(p) j %in% p$outputs, logical(1)))
    if (length(idx) == 0L) next
    solved <- cora_petrick(lapply(pis[idx], function(p) p$coverage))
    if (length(solved$sums) == 0L) next
    per_output[[length(per_output) + 1L]] <-
      lapply(solved$sums, function(s) sort(idx[s]))
  }
  if (length(per_output) == 0L) {
    out <- structure(list(), class = "cora_systems")
    return(out)
  }
  combined <- Reduce(boolean_multiply_sets, per_output)

  out <- lapply(seq_along(combined), function(i) {
    chosen <- combined[[i]]
    single <- lapply(seq_len(n_out), function(j) {
      pis[chosen[vapply(pis[chosen], function(p) j %in% p$outputs, logical(1))]]
    })
    new_irredundant_system_multi(ctx, single, i)
  })
  class(out) <- "cora_systems"
  ctx$irredundant_systems <- out
  out
}
