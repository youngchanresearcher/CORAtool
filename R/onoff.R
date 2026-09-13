## The ON-OFF algorithm: McCluskey's modified minimisation, which derives
## implicants by contrasting every positive row with the negative rows.

## --------------------------------------------------- single-outcome variant

## Contrasts one positive row with every negative row, keeping the literals
## that distinguish them.
reduce_with_off_set <- function(minterm, coverage, off_matrix) {
  n <- length(minterm)
  res <- vector("list", nrow(off_matrix))
  for (r in seq_len(nrow(off_matrix))) {
    elm <- off_matrix[r, ]
    new_minterm <- ifelse(minterm != elm, minterm, -1L)
    res[[r]] <- list(minterm = as.integer(new_minterm), coverage = coverage)
  }
  res
}

## Two row terms combine when exactly one position differs and the
## difference is an eliminated literal on one of the two sides.
row_can_be_reduced <- function(a, b) {
  diff <- 0L
  for (i in seq_along(a)) {
    if (a[[i]] != b[[i]] && (a[[i]] == -1L || b[[i]] == -1L)) {
      diff <- diff + 1L
      if (diff > 1L) return(FALSE)
    }
  }
  diff == 1L
}

row_reduce <- function(a, b) ifelse(a == b, a, -1L)

## Repeatedly merges the rows of a contrast matrix until nothing changes.
onoff_reduction <- function(matrix_items, tags = NULL) {
  items <- matrix_items
  repeat {
    any_reduction <- FALSE
    n <- length(items)
    used <- rep(FALSE, n)
    new_items <- list()
    for (i in seq_len(n)) {
      if (i == n) break
      for (j in seq.int(i + 1L, n)) {
        if (used[i] || used[j]) next
        a <- items[[i]]; b <- items[[j]]
        same_tag <- is.null(a$tag) || identical(a$tag, b$tag)
        if (same_tag && row_can_be_reduced(a$minterm, b$minterm)) {
          el <- list(minterm = as.integer(row_reduce(a$minterm, b$minterm)),
                     coverage = a$coverage)
          if (!is.null(a$tag)) el$tag <- a$tag
          new_items[[length(new_items) + 1L]] <- el
          any_reduction <- TRUE
          used[i] <- TRUE
          used[j] <- TRUE
        }
      }
    }
    for (i in seq_len(n)) if (!used[i]) new_items[[length(new_items) + 1L]] <- items[[i]]
    items <- new_items
    if (!any_reduction) break
  }
  items
}

on_off_grouping <- function(pdata, in_cols, output) {
  out <- pdata[[output]]
  on_rows <- which(out == 1L)
  off_rows <- which(out == 0L)
  in_mat <- as.matrix(pdata[in_cols])
  storage.mode(in_mat) <- "integer"
  list(
    onset = lapply(on_rows, function(r) {
      list(minterm = in_mat[r, ], coverage = r - 1L)
    }),
    offset = in_mat[off_rows, , drop = FALSE]
  )
}

onoff_reduction_single <- function(onset, offset, base) {
  keys <- character(0)
  implicants <- list()
  coverages <- list()
  for (mt in onset) {
    contrast <- reduce_with_off_set(mt$minterm, mt$coverage, offset)
    reduced <- onoff_reduction(contrast)
    if (length(reduced) == 0L) next
    coverage <- reduced[[1L]]$coverage
    products <- bool_multiply(lapply(reduced, function(x) x$minterm), base)
    for (p in products) {
      k <- int_key(p)
      pos <- match(k, keys)
      if (is.na(pos)) {
        keys <- c(keys, k)
        implicants[[length(implicants) + 1L]] <- p
        coverages[[length(coverages) + 1L]] <- coverage
      } else {
        coverages[[pos]] <- set_union(coverages[[pos]], coverage)
      }
    }
  }
  list(implicants = implicants, coverages = coverages)
}

## ------------------------------------------------- essential prime implicants

create_weight_groups <- function(rows, extra) {
  if (nrow(rows) == 0L) {
    return(vector("list", extra))
  }
  max_len <- ncol(rows) + extra
  groups <- vector("list", max_len)
  for (i in seq_along(groups)) groups[[i]] <- list()
  for (r in seq_len(nrow(rows))) {
    x <- as.integer(rows[r, ])
    w <- sum(x != 0L)
    groups[[w + 1L]][[length(groups[[w + 1L]]) + 1L]] <- x
  }
  groups
}

are_reducable <- function(a, b) sum(a != b) == 1L

## Keeps only the single literal on which the two terms disagree.
single_difference <- function(a, b) {
  e <- rep(-1L, length(a))
  idx <- which(a != b)
  e[idx] <- a[idx]
  e
}

## Compares every positive term of weight w with the negative terms of
## weight w-1, w and w+1, collecting the distinguishing literals.
compare_the_groups <- function(P, S, multi_value) {
  l <- length(P)
  res <- vector("list", l)
  for (ind in seq_len(l)) {
    res[[ind]] <- list()
    for (ind2 in seq_along(P[[ind]])) {
      el1 <- P[[ind]][[ind2]]
      acc <- list()
      acc_keys <- character(0)
      add <- function(x) {
        k <- int_key(x)
        if (!(k %in% acc_keys)) {
          acc[[length(acc) + 1L]] <<- x
          acc_keys <<- c(acc_keys, k)
        }
      }
      neighbours <- if (multi_value) c(ind + 1L, ind, ind - 1L) else c(ind + 1L, ind - 1L)
      for (nb in neighbours) {
        if (nb < 1L || nb > length(S)) next
        for (el2 in S[[nb]]) {
          if (are_reducable(el1, el2)) add(single_difference(el1, el2))
        }
      }
      res[[ind]][[ind2]] <- acc
    }
  }
  res
}

merge_elements <- function(a, b) pmax(a, b)

## An implicant candidate is the union of one literal picked per contrast.
combine_an_implicant <- function(groups, base) {
  keys <- character(0)
  res <- list()
  for (group in groups) {
    for (subgroup in group) {
      if (length(subgroup) == 0L) next
      merged <- Reduce(merge_elements, subgroup)
      k <- int_key(merged)
      if (!(k %in% keys)) {
        keys <- c(keys, k)
        res[[length(res) + 1L]] <- as.integer(merged)
      }
    }
  }
  res
}

## TRUE when the candidate also covers a negative row, which disqualifies it.
included_in_offset <- function(implicant, offset) {
  fixed <- which(implicant >= 0L)
  if (length(fixed) == 0L) return(nrow(offset) > 0L)
  if (nrow(offset) == 0L) return(FALSE)
  hits <- rep(TRUE, nrow(offset))
  for (i in fixed) hits <- hits & (offset[, i] == implicant[[i]])
  any(hits)
}

## Zero-based truth table rows covered by each essential implicant.
reduce_the_onset <- function(essentials, pdata, in_cols, output) {
  on_rows <- which(pdata[[output]] == 1L)
  in_mat <- as.matrix(pdata[in_cols])
  storage.mode(in_mat) <- "integer"
  lapply(essentials, function(imp) {
    fixed <- which(imp >= 0L)
    hits <- rep(TRUE, length(on_rows))
    for (i in fixed) hits <- hits & (in_mat[on_rows, i] == imp[[i]])
    on_rows[hits] - 1L
  })
}

get_essential_implicants <- function(pdata, in_cols, output, levels, base) {
  in_mat <- as.matrix(pdata[in_cols])
  storage.mode(in_mat) <- "integer"
  onset <- in_mat[pdata[[output]] == 1L, , drop = FALSE]
  offset <- in_mat[pdata[[output]] == 0L, , drop = FALSE]
  if (nrow(onset) == 0L) return(list())
  P <- create_weight_groups(onset, 1L)
  S <- create_weight_groups(offset, 2L)
  if (length(S) < length(P) + 1L) {
    length(S) <- length(P) + 1L
    S[vapply(S, is.null, logical(1))] <- list(list())
  }
  groups <- compare_the_groups(P, S, max(levels) > 2L)
  candidates <- combine_an_implicant(groups, base)
  Filter(function(imp) !included_in_offset(imp, offset), candidates)
}

## ---------------------------------------------------- multi-outcome variant

on_off_grouping_mo <- function(pdata, in_cols, out_cols) {
  in_mat <- as.matrix(pdata[in_cols])
  storage.mode(in_mat) <- "integer"
  out_mat <- as.matrix(pdata[out_cols])
  storage.mode(out_mat) <- "integer"

  on_rows <- which(apply(out_mat == 1L, 1L, any))
  off_rows <- which(!apply(out_mat == 1L, 1L, all))

  onset <- lapply(on_rows, function(r) {
    list(minterm = in_mat[r, ], coverage = r - 1L, tag = out_mat[r, ])
  })
  offset <- list(
    data = in_mat[off_rows, , drop = FALSE],
    tags = 1L - out_mat[off_rows, , drop = FALSE]
  )
  list(onset = onset, offset = offset)
}

## Contrasts a positive row with the negative rows, intersecting the outcome
## tags so that only outcomes the contrast speaks to survive.
reduce_with_off_set_mo <- function(mt, offset) {
  res <- list()
  n_off <- nrow(offset$data)
  for (r in seq_len(n_off)) {
    elm <- offset$data[r, ]
    new_minterm <- as.integer(ifelse(mt$minterm != elm, mt$minterm, -1L))
    new_tag <- as.integer(offset$tags[r, ] * mt$tag)
    if (any(new_tag != 0L)) {
      res[[length(res) + 1L]] <- list(minterm = new_minterm,
                                      coverage = mt$coverage,
                                      tag = new_tag)
    }
  }
  res
}

## Every non-empty subset of outcomes, in the bit order used by the reference
## implementation (bit i set means outcome i participates).
outcome_masks <- function(tag_length) {
  lapply(seq_len(2L^tag_length - 1L), function(x) {
    bits <- integer(tag_length)
    for (i in seq_len(tag_length)) {
      bits[[i]] <- bitwAnd(x, 1L)
      x <- bitwShiftR(x, 1L)
    }
    bits
  })
}

onoff_reduction_mo <- function(onset, offset, base) {
  tag_length <- length(onset[[1L]]$tag)
  masks <- outcome_masks(tag_length)
  acc <- list()
  for (mt in onset) {
    reduced <- onoff_reduction(reduce_with_off_set_mo(mt, offset))
    for (mask in masks) {
      current <- Filter(function(x) any(mask > 0L & x$tag > 0L), reduced)
      if (length(current) == 0L) next
      products <- bool_multiply(lapply(current, function(x) x$minterm), base)
      if (length(products) == 0L) next
      key <- int_key(rev(mask))
      acc[[key]] <- c(acc[[key]], products)
    }
  }
  acc
}

prime_implicants_on_off <- function(ctx) {
  preprocess_data(ctx)
  pdata <- ctx$preprocessed_data
  in_cols <- ctx$input_labels
  out_cols <- ctx$output_labels

  ## Constant outcome columns carry no contrast; fall back to ON-DC.
  constant <- vapply(pdata[out_cols], function(v) length(unique(v)) == 1L,
                     logical(1))
  if (all(constant)) return(prime_implicants_on_dc(ctx))

  ctx$levels <- context_levels(ctx)
  ctx$value_sets <- context_value_sets(ctx)
  ctx$labels <- in_cols
  base <- literal_base(ctx$levels)

  if (ctx$multi_output) {
    out_mat <- as.matrix(pdata[out_cols])
    ctx$cares <- which(apply(out_mat == 1L, 1L, any)) - 1L
    grouping <- on_off_grouping_mo(pdata, in_cols, out_cols)
    acc <- onoff_reduction_mo(grouping$onset, grouping$offset, base)

    in_mat <- as.matrix(pdata[in_cols])
    storage.mode(in_mat) <- "integer"
    res <- list()
    res_keys <- character(0)
    for (products in acc) {
      for (p in products) {
        raw <- transform_to_raw_implicant(p, ctx$value_sets, base)
        rows <- which(vapply(seq_len(nrow(in_mat)), function(r) {
          row_in_minterm(in_mat[r, ], raw)
        }, logical(1)))
        o_tag <- output_coverage_of_pi(pdata, in_mat, out_cols, raw)
        key <- minterm_key(raw)
        pos <- match(key, res_keys)
        if (is.na(pos)) {
          res_keys <- c(res_keys, key)
          res[[length(res) + 1L]] <- new_implicant_mo(
            ctx,
            implicant = minterm_to_str(raw, ctx$levels, ctx$labels),
            raw_implicant = raw,
            coverage = rows - 1L,
            outputs = o_tag
          )
        } else {
          res[[pos]]$outputs <- sort(union(res[[pos]]$outputs, o_tag))
        }
      }
    }
    return(res)
  }

  output <- out_cols[[1L]]
  if (all(pdata[[output]] == 1L)) return(prime_implicants_on_dc(ctx))
  ctx$cares <- which(pdata[[output]] == 1L) - 1L

  prime_implicants <- list()
  essentials <- get_essential_implicants(pdata, in_cols, output, ctx$levels, base)
  if (length(essentials) > 0L) {
    cov_essentials <- reduce_the_onset(essentials, pdata, in_cols, output)
    for (i in seq_along(essentials)) {
      raw <- row_term_to_raw_implicant(essentials[[i]], ctx$value_sets)
      prime_implicants[[length(prime_implicants) + 1L]] <- new_implicant(
        ctx,
        implicant = minterm_to_str(raw, ctx$levels, ctx$labels),
        raw_implicant = raw,
        coverage = sort(cov_essentials[[i]]),
        essential = TRUE
      )
    }
    covered <- sort(unique(unlist(cov_essentials, use.names = FALSE)))
    reduced_data <- pdata[-(covered + 1L), , drop = FALSE]
    grouping <- on_off_grouping(reduced_data, in_cols, output)
    ## Coverage indices must stay relative to the full truth table.
    remaining <- setdiff(seq_len(nrow(pdata)) - 1L, covered)
    on_rows <- which(reduced_data[[output]] == 1L)
    for (k in seq_along(grouping$onset)) {
      grouping$onset[[k]]$coverage <- remaining[on_rows[[k]]]
    }
  } else {
    grouping <- on_off_grouping(pdata, in_cols, output)
  }

  reduction <- onoff_reduction_single(grouping$onset, grouping$offset, base)
  for (i in seq_along(reduction$implicants)) {
    raw <- transform_to_raw_implicant(reduction$implicants[[i]], ctx$value_sets, base)
    prime_implicants[[length(prime_implicants) + 1L]] <- new_implicant(
      ctx,
      implicant = minterm_to_str(raw, ctx$levels, ctx$labels),
      raw_implicant = raw,
      coverage = sort(reduction$coverages[[i]]),
      essential = FALSE
    )
  }
  prime_implicants
}

## Outcomes that a prime implicant covers without exception.
output_coverage_of_pi <- function(pdata, in_mat, out_cols, raw_implicant) {
  hits <- vapply(seq_len(nrow(in_mat)), function(r) {
    row_in_minterm(in_mat[r, ], raw_implicant)
  }, logical(1))
  res <- integer(0)
  for (i in seq_along(out_cols)) {
    vals <- pdata[[out_cols[[i]]]][hits]
    if (length(vals) == 0L || all(vals == 1L)) res <- c(res, i)
  }
  as.integer(res)
}
