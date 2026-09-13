## Petrick's method: derives every irredundant sum from a prime implicant
## chart by multiplying out the coverage conditions with absorption.

## Boolean multiplication of two sums of products. Each product is a sorted
## integer vector; absorption keeps only the minimal products.
boolean_multiply_sets <- function(x, y) {
  res <- list()
  res_keys <- character(0)
  for (xi in x) {
    for (yi in y) {
      tmp <- sort(unique(c(xi, yi)))
      if (length(res)) {
        ## X + XY = X: drop products that contain the new one ...
        keep <- !vapply(res, function(z) all(tmp %in% z), logical(1))
        res <- res[keep]
        res_keys <- res_keys[keep]
        ## ... and skip the new one when it contains an existing product.
        if (any(vapply(res, function(z) all(z %in% tmp), logical(1)))) next
      }
      key <- int_key(tmp)
      if (!(key %in% res_keys)) {
        res[[length(res) + 1L]] <- tmp
        res_keys <- c(res_keys, key)
      }
    }
  }
  res
}

#' Solve a prime implicant chart with Petrick's method
#'
#' @param coverages A list with one integer vector per prime implicant giving
#'   the rows that implicant covers.
#'
#' @return A list with `essential`, the indices of the prime implicants that
#'   are the only cover of some row, and `sums`, a list of integer vectors
#'   holding the prime implicant indices of every irredundant sum. Indices
#'   are one-based positions in `coverages`.
#'
#' @examples
#' cora_petrick(list(c(1, 2), c(2, 3), c(3, 4)))
#' @export
cora_petrick <- function(coverages) {
  if (length(coverages) == 0L) return(list(essential = integer(0), sums = list()))

  ## Prime implicants with identical coverage are interchangeable; solve once
  ## and expand the solutions afterwards.
  keys <- vapply(coverages, function(cv) cov_key(sort(cv)), character(1))
  uniq_keys <- unique(keys)
  orig_idx <- lapply(uniq_keys, function(k) which(keys == k))
  dedup_cov <- lapply(orig_idx, function(ii) sort(unique(coverages[[ii[[1L]]]])))

  rows <- sort(unique(unlist(dedup_cov, use.names = FALSE)))
  if (length(rows) == 0L) return(list(essential = integer(0), sums = list()))

  row_to_impl <- lapply(rows, function(r) {
    which(vapply(dedup_cov, function(cv) r %in% cv, logical(1)))
  })

  essential_dedup <- unique(unlist(
    lapply(row_to_impl, function(s) if (length(s) == 1L) s else integer(0)),
    use.names = FALSE
  ))
  essential <- sort(unlist(
    lapply(essential_dedup, function(i) {
      if (length(orig_idx[[i]]) == 1L) orig_idx[[i]] else integer(0)
    }),
    use.names = FALSE
  ))
  if (is.null(essential)) essential <- integer(0)

  ## Multiply the coverage conditions, cheapest first.
  mult_in <- lapply(row_to_impl, function(s) lapply(s, function(i) as.integer(i)))
  mult_in <- mult_in[order(vapply(mult_in, length, integer(1)))]
  res <- Reduce(boolean_multiply_sets, mult_in)

  ## Expand deduplicated solutions back to the original prime implicants.
  sums <- list()
  for (sum_idx in res) {
    choices <- lapply(sum_idx, function(i) orig_idx[[i]])
    grid <- cartesian_product(choices)
    for (r in seq_len(nrow(grid))) {
      sums[[length(sums) + 1L]] <- sort(as.integer(grid[r, ]))
    }
  }
  ## Deterministic order: shorter solutions first, then lexicographic.
  if (length(sums) > 1L) {
    ord <- order(vapply(sums, length, integer(1)),
                 vapply(sums, int_key, character(1)))
    sums <- sums[ord]
  }
  list(essential = as.integer(essential), sums = sums)
}
