## Petrick's method: derives every irredundant sum from a prime implicant
## chart by multiplying out the coverage conditions with absorption.

## Products of implicant indices are held as bit masks (30 bits per word),
## so that absorption can test a whole sum of products at once.
MASK_BITS <- 30L

idx_to_mask <- function(v, nwords) {
  m <- integer(nwords)
  if (length(v) == 0L) return(m)
  w <- (v - 1L) %/% MASK_BITS + 1L
  b <- (v - 1L) %% MASK_BITS
  for (i in seq_along(v)) m[[w[[i]]]] <- bitwOr(m[[w[[i]]]], bitwShiftL(1L, b[[i]]))
  m
}

mask_to_idx <- function(m) {
  out <- integer(0)
  for (w in seq_along(m)) {
    if (m[[w]] == 0L) next
    bits <- 0:(MASK_BITS - 1L)
    set <- bits[bitwAnd(m[[w]], bitwShiftL(1L, bits)) != 0L]
    out <- c(out, (w - 1L) * MASK_BITS + set + 1L)
  }
  out
}

## Boolean multiplication of two sums of products, with absorption
## (X + XY = X) applied eagerly so that only minimal products survive.
boolean_multiply_sets <- function(x, y) {
  if (length(x) == 0L || length(y) == 0L) return(list())
  maxi <- max(c(unlist(x, use.names = FALSE), unlist(y, use.names = FALSE)))
  nw <- (maxi - 1L) %/% MASK_BITS + 1L
  xm <- lapply(x, idx_to_mask, nwords = nw)
  ym <- lapply(y, idx_to_mask, nwords = nw)

  res <- matrix(integer(0), nrow = 0L, ncol = nw)
  for (a in xm) {
    for (b in ym) {
      tmp <- bitwOr(a, b)
      if (nrow(res) > 0L) {
        rep_tmp <- rep(tmp, each = nrow(res))
        anded <- matrix(bitwAnd(res, rep_tmp), nrow = nrow(res))
        ## Drop stored products that contain the new one ...
        contains <- rowSums(anded != rep_tmp) == 0L
        if (any(contains)) {
          res <- res[!contains, , drop = FALSE]
          anded <- anded[!contains, , drop = FALSE]
          rep_tmp <- rep(tmp, each = nrow(res))
        }
        ## ... and skip the new one when it contains a stored product.
        if (nrow(res) > 0L &&
            any(rowSums(anded != res) == 0L)) {
          next
        }
      }
      res <- rbind(res, tmp)
    }
  }
  lapply(seq_len(nrow(res)), function(i) mask_to_idx(res[i, ]))
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
