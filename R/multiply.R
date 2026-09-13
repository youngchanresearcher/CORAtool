## Boolean multiplication over "row terms" (integer vectors in which -1 marks
## an eliminated literal), with absorption (X + XY = X) applied eagerly.
##
## A literal is encoded as a single integer `column * literal_base + value`
## so that products can be held as sorted integer vectors.

literal_base <- function(levels) as.integer(max(c(levels, 2L))) + 1L

encode_literal <- function(col0, value, base) as.integer(col0 * base + value)

decode_literal <- function(code, base) {
  list(column = code %/% base, value = code %% base)
}

## Multiplies out the rows of `m`, returning a list of sorted integer vectors
## (each one a product of literals) that form an irredundant sum of products.
bool_multiply <- function(m, base) {
  sets_to_multiply <- list()
  for (row in m) {
    keep <- which(row != -1L)
    if (length(keep) == 0L) {
      sets_to_multiply[[length(sets_to_multiply) + 1L]] <- list()
      next
    }
    sets_to_multiply[[length(sets_to_multiply) + 1L]] <-
      lapply(keep, function(i) encode_literal(i - 1L, row[[i]], base))
  }
  if (length(sets_to_multiply) == 0L) return(list())

  res <- sets_to_multiply[[1L]]
  for (k in seq_along(sets_to_multiply)[-1L]) {
    tmp <- list()
    tmp_keys <- character(0)
    for (x in res) {
      for (y in sets_to_multiply[[k]]) {
        new_el <- sort(unique(c(x, y)))
        ## Skip when an existing term is already contained in the new one.
        if (length(tmp) && any(vapply(tmp, function(z) all(z %in% new_el),
                                      logical(1)))) {
          next
        }
        ## Drop existing terms that contain the new one.
        if (length(tmp)) {
          keep <- !vapply(tmp, function(z) all(new_el %in% z), logical(1))
          tmp <- tmp[keep]
          tmp_keys <- tmp_keys[keep]
        }
        key <- int_key(new_el)
        if (!(key %in% tmp_keys)) {
          tmp[[length(tmp) + 1L]] <- new_el
          tmp_keys <- c(tmp_keys, key)
        }
      }
    }
    res <- tmp
  }
  res
}

## Expands a product of literals into the canonical minterm representation:
## one value set per input column, and for a free literal the values the
## condition actually takes. Deriving that set from the number of levels
## instead would assume the coding starts at zero, and would drop every row
## whose value falls outside {0, ..., levels - 1}.
transform_to_raw_implicant <- function(impl, value_sets, base) {
  res <- lapply(value_sets, as.integer)
  for (code in impl) {
    d <- decode_literal(code, base)
    res[[d$column + 1L]] <- as.integer(d$value)
  }
  res
}

## Same, but from a row term (-1 marking free literals).
row_term_to_raw_implicant <- function(term, value_sets) {
  res <- lapply(value_sets, as.integer)
  for (i in seq_along(term)) {
    if (term[[i]] != -1L) res[[i]] <- as.integer(term[[i]])
  }
  res
}
