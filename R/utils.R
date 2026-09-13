## Internal helpers shared by the optimisation algorithms.
##
## Two term representations are used throughout the package, mirroring the
## reference implementation:
##
##   * a "minterm" is a list with one integer vector (a value set) per input
##     column; it is used by the ON-DC algorithm and as the canonical
##     "raw implicant" representation everywhere else.
##   * a "row term" is an integer vector with one entry per input column and
##     -1 marking an eliminated (don't care) literal; it is used by the
##     ON-OFF algorithm.

## Decimal rounding that follows the same round-half-to-even rule on the
## decimal representation as Python's built-in round(), so that inclusion
## scores agree with the reference implementation to the last digit.
py_round <- function(x, digits) {
  out <- as.numeric(sprintf("%.*f", as.integer(digits), x))
  out[is.na(x)] <- NA_real_
  out
}

## Keys used to emulate hash-set semantics with R environments.
set_key <- function(s) paste0(s, collapse = ",")

minterm_key <- function(m) {
  paste0(vapply(m, set_key, character(1)), collapse = "|")
}

## Coverage vectors are kept sorted by set_union(), so no re-sorting here.
cov_key <- function(cov) paste0(cov, collapse = ",")

int_key <- function(v) paste0(v, collapse = ",")

## An insertion-ordered set of arbitrary items, keyed by a character key.
## Insertion order is what makes the R results reproducible from run to run.
ordered_set <- function() {
  e <- new.env(parent = emptyenv(), hash = TRUE)
  structure(list(env = e, items = list(), n = 0L), class = "ordered_set")
}

os_add <- function(os, key, value) {
  if (!is.null(os$env[[key]])) return(os)
  os$n <- os$n + 1L
  assign(key, os$n, envir = os$env)
  os$items[[os$n]] <- value
  os
}

os_has <- function(os, key) !is.null(os$env[[key]])

os_items <- function(os) os$items

## Set helpers on sorted integer vectors. The union is on the hot path of
## the minimisation, so it avoids the cost of dispatching to sort().
set_union <- function(a, b) {
  if (length(a) == 0L) return(b)
  if (length(b) == 0L) return(a)
  u <- c(a, b)
  u <- u[!duplicated.default(u)]
  if (length(u) == length(a)) return(a)
  u[order(u)]
}

is_subset <- function(a, b) all(a %in% b)

## TRUE when every value of `row` lies in the corresponding value set of
## `minterm` (i.e. the minterm covers the row).
row_in_minterm <- function(row, minterm) {
  for (i in seq_along(row)) {
    if (!(row[[i]] %in% minterm[[i]])) return(FALSE)
  }
  TRUE
}

## TRUE when minterm `a` is contained in minterm `b`, set-wise per column.
minterm_subset <- function(a, b) {
  for (i in seq_along(a)) {
    if (!all(a[[i]] %in% b[[i]])) return(FALSE)
  }
  TRUE
}

## Cartesian product with the LAST factor varying fastest, matching
## itertools.product(); returns an integer matrix of all combinations.
cartesian_product <- function(dims) {
  n <- vapply(dims, length, integer(1))
  total <- prod(n)
  if (total == 0) {
    return(matrix(integer(0), nrow = 0, ncol = length(dims)))
  }
  res <- matrix(0L, nrow = total, ncol = length(dims))
  rep_inner <- 1L
  for (j in rev(seq_along(dims))) {
    res[, j] <- rep(rep(dims[[j]], each = rep_inner), length.out = total)
    rep_inner <- rep_inner * n[[j]]
  }
  res
}

## Unique values in order of first appearance (pandas.unique semantics).
unique_in_order <- function(x) unique(x)

stopf <- function(...) stop(sprintf(...), call. = FALSE)
