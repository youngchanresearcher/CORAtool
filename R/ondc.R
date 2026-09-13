## The ON-DC algorithm: the classical Quine-McCluskey minimisation operating
## on positive and don't care terms.
##
## Inside this file a minterm is an integer vector with one bit mask per
## input column, a value set {0, 2} becoming the mask 2^0 + 2^2. Masks let
## the reduction step compare a whole group of terms at once, which is what
## makes the minimisation fast enough in R. Terms cross the boundary of this
## file in the list-of-value-sets form the rest of the package uses.

MAX_LEVELS <- 30L

## ON-DC merges subsets of a condition's value set, so its cost grows
## exponentially in the number of levels of a single condition: a third of a
## second at twelve levels, half a minute at eighteen, and out of reach at
## thirty (the figures move with the machine, the rate does not). ON-OFF returns
## the same prime implicants from the observed rows in a fraction of a second
## at any size, so the only thing to do here is say so before the wait.
WARN_LEVELS <- 12L

warn_many_levels <- function(levels, labels) {
  wide <- which(levels > WARN_LEVELS)
  if (length(wide) == 0L) return(invisible(NULL))
  warning(sprintf(paste0(
    "Condition(s) %s have more than %d levels. The \"ON-DC\" algorithm ",
    "takes exponentially longer as a condition gains levels, and may not ",
    "finish. Use algorithm = \"ON-OFF\", which returns the same prime ",
    "implicants from the observed rows."),
    paste(sQuote(unlist(labels)[wide], q = FALSE), collapse = ", "),
    WARN_LEVELS), call. = FALSE)
  invisible(NULL)
}

mask_of <- function(values) {
  if (length(values) == 0L) return(0L)
  sum(bitwShiftL(1L, as.integer(values)))
}

mask_to_values <- function(m) {
  if (m == 0L) return(integer(0))
  bits <- 0:(MAX_LEVELS)
  bits[bitwAnd(m, bitwShiftL(1L, bits)) != 0L]
}

mask_minterm_to_list <- function(masks) lapply(masks, mask_to_values)

## Number of literals not fixed to the single value {0}.
count_non_zeros_mask <- function(masks) sum(masks != 1L)

## Groups minterms by their number of non-zero literals. `cares` holds the
## zero-based indices of the positive rows; `outputcolumns` is the outcome
## matrix of those rows (multi-output only).
create_groups <- function(table, column_number, cares, outputcolumns,
                          multi_output) {
  n_rows <- nrow(table)
  mask_mat <- matrix(bitwShiftL(1L, table), nrow = n_rows)
  weights <- rowSums(mask_mat != 1L)

  is_care <- (seq_len(n_rows) - 1L) %in% cares
  n_out <- if (multi_output) nrow(outputcolumns) else 0L
  full_tag <- if (multi_output) sum(bitwShiftL(1L, seq_len(n_out) - 1L)) else 0L

  tags <- integer(n_rows)
  if (multi_output) {
    care_index <- 0L
    for (r in seq_len(n_rows)) {
      if (is_care[r]) {
        care_index <- care_index + 1L
        on <- which(outputcolumns[, care_index] == 1L)
        tags[r] <- mask_of(on - 1L)
      } else {
        tags[r] <- full_tag
      }
    }
  }

  keep <- if (multi_output) tags != 0L else rep(TRUE, n_rows)
  groups <- vector("list", column_number + 1L)
  for (w in seq_along(groups)) {
    idx <- which(keep & weights == (w - 1L))
    groups[[w]] <- list(
      masks = mask_mat[idx, , drop = FALSE],
      coverage = lapply(idx, function(r) {
        if (is_care[r]) r - 1L else integer(0)
      }),
      tag = if (multi_output) tags[idx] else integer(length(idx))
    )
  }
  groups
}

group_size <- function(g) nrow(g$masks)

element_key_mask <- function(masks, coverage, tag, multi_output) {
  if (multi_output) {
    paste0(paste0(masks, collapse = ","), "#",
           paste0(coverage, collapse = ","), "#", tag)
  } else {
    paste0(paste0(masks, collapse = ","), "#",
           paste0(coverage, collapse = ","))
  }
}

## One elimination pass. Terms that differ in exactly one literal combine;
## those that never combine are prime implicants.
reduction_step <- function(groups, n, multi_output) {
  was_any_reduction <- FALSE
  new_masks <- vector("list", n + 1L)
  new_cov <- vector("list", n + 1L)
  new_tag <- vector("list", n + 1L)
  new_keys <- vector("list", n + 1L)
  for (w in seq_len(n + 1L)) {
    new_masks[[w]] <- list(); new_cov[[w]] <- list()
    new_tag[[w]] <- integer(0)
    new_keys[[w]] <- new.env(parent = emptyenv(), hash = TRUE)
  }
  reduced <- lapply(groups, function(g) rep(FALSE, group_size(g)))

  add_new <- function(w, masks, coverage, tag) {
    key <- element_key_mask(masks, coverage, tag, multi_output)
    seen <- new_keys[[w]]
    if (!is.null(seen[[key]])) return(invisible(NULL))
    assign(key, TRUE, envir = seen)
    k <- length(new_masks[[w]]) + 1L
    new_masks[[w]][[k]] <<- masks
    new_cov[[w]][[k]] <<- coverage
    new_tag[[w]][[k]] <<- tag
    invisible(NULL)
  }

  ## `wa` and `wb` are the weight classes being compared; within one class a
  ## term is never compared with itself.
  compare <- function(wa, wb) {
    ga <- groups[[wa]]; gb <- groups[[wb]]
    na <- group_size(ga); nb <- group_size(gb)
    if (na == 0L || nb == 0L) return(invisible(NULL))
    for (i in seq_len(na)) {
      row <- ga$masks[i, ]
      diff_mat <- gb$masks != rep(row, each = nb)
      diffs <- if (ncol(gb$masks) == 1L) as.integer(diff_mat)
               else rowSums(diff_mat)
      cand <- which(diffs == 1L)
      if (wa == wb) cand <- cand[cand != i]
      if (length(cand) == 0L) next
      if (multi_output) {
        inter <- bitwAnd(ga$tag[[i]], gb$tag[cand])
        cand <- cand[inter != 0L]
        if (length(cand) == 0L) next
      }
      for (j in cand) {
        merged <- row
        col <- which(diff_mat[j, ])
        merged[col] <- bitwOr(row[col], gb$masks[j, col])
        coverage <- set_union(ga$coverage[[i]], gb$coverage[[j]])
        tag <- 0L
        if (multi_output) {
          tag <- bitwAnd(ga$tag[[i]], gb$tag[[j]])
          if (tag == ga$tag[[i]]) reduced[[wa]][i] <<- TRUE
          if (tag == gb$tag[[j]]) reduced[[wb]][j] <<- TRUE
        } else {
          reduced[[wa]][i] <<- TRUE
          reduced[[wb]][j] <<- TRUE
        }
        add_new(wa, merged, coverage, tag)
        was_any_reduction <<- TRUE
      }
    }
    invisible(NULL)
  }

  for (w in seq_len(n)) compare(w, w + 1L)
  for (w in seq_len(n + 1L)) compare(w, w)

  finals <- list()
  final_keys <- new.env(parent = emptyenv(), hash = TRUE)
  for (w in seq_len(n + 1L)) {
    g <- groups[[w]]
    for (i in seq_len(group_size(g))) {
      if (reduced[[w]][i] || length(g$coverage[[i]]) == 0L) next
      masks <- g$masks[i, ]
      key <- element_key_mask(masks, g$coverage[[i]], g$tag[[i]], multi_output)
      if (!is.null(final_keys[[key]])) next
      assign(key, TRUE, envir = final_keys)
      finals[[length(finals) + 1L]] <- list(masks = masks,
                                            coverage = g$coverage[[i]],
                                            tag = g$tag[[i]])
    }
  }

  next_groups <- lapply(seq_len(n + 1L), function(w) {
    k <- length(new_masks[[w]])
    list(
      masks = if (k == 0L) matrix(integer(0), nrow = 0L, ncol = n)
              else do.call(rbind, new_masks[[w]]),
      coverage = new_cov[[w]],
      tag = new_tag[[w]]
    )
  })

  list(groups = next_groups, implicants = finals,
       reduction = was_any_reduction)
}

## Splits literals that are neither singletons nor full domains, so that
## every surviving term is a genuine implicant of the configuration space.
decompose_element <- function(el, levels, multi_output) {
  n <- length(el$masks)
  options <- vector("list", n)
  for (i in seq_len(n)) {
    values <- mask_to_values(el$masks[[i]])
    ## A literal is left alone when it names one value or the whole domain;
    ## the domain is recognised by its size, as the values need not start
    ## at zero.
    if (length(values) == 1L || length(values) == levels[[i]]) {
      options[[i]] <- el$masks[[i]]
    } else {
      options[[i]] <- bitwShiftL(1L, values)
    }
  }
  counts <- vapply(options, length, integer(1))
  if (all(counts == 1L)) return(list(el))
  idx <- cartesian_product(lapply(counts, seq_len))
  lapply(seq_len(nrow(idx)), function(r) {
    list(masks = vapply(seq_len(n), function(i) options[[i]][[idx[r, i]]],
                        integer(1)),
         coverage = el$coverage,
         tag = el$tag)
  })
}

eliminate_minterms <- function(table, elements, levels, multi_output) {
  decomposed <- list()
  for (el in elements) {
    decomposed <- c(decomposed, decompose_element(el, levels, multi_output))
  }

  ## Restrict every decomposed term to the rows it still covers.
  row_masks <- matrix(bitwShiftL(1L, table), nrow = nrow(table))
  kept <- list()
  for (el in decomposed) {
    cov <- el$coverage
    if (length(cov)) {
      rows <- row_masks[cov + 1L, , drop = FALSE]
      ## bitwAnd() drops dimensions, so rebuild the matrix before reducing.
      anded <- matrix(bitwAnd(rows, rep(el$masks, each = nrow(rows))),
                      nrow = nrow(rows))
      hit <- rowSums(anded == 0L) == 0L
      el$coverage <- cov[hit]
    }
    if (length(el$coverage) > 0L) kept[[length(kept) + 1L]] <- el
  }

  n <- length(kept)
  if (n == 0L) return(list())
  mat <- do.call(rbind, lapply(kept, function(e) e$masks))
  tags <- vapply(kept, function(e) e$tag, integer(1))
  eliminated <- rep(FALSE, n)
  for (i in seq_len(n)) {
    for (j in seq_len(n)) {
      if (j <= i) next
      a <- mat[i, ]; b <- mat[j, ]
      a_in_b <- all(bitwAnd(a, b) == a)
      if (a_in_b && (!multi_output || bitwAnd(tags[[i]], tags[[j]]) == tags[[i]])) {
        eliminated[i] <- TRUE
      } else if (all(bitwAnd(b, a) == b) &&
                 (!multi_output || bitwAnd(tags[[j]], tags[[i]]) == tags[[j]])) {
        eliminated[j] <- TRUE
      }
    }
  }
  kept[!eliminated]
}

## ------------------------------------------------------------- term printing

## Every literal states its value, so a term reads the same whatever the
## conditions are coded as. The upper/lower case convention it replaces
## marked a negated literal by the presence of 0 in its value set, which
## says nothing at all when a condition is coded without a zero.
set_to_str <- function(s, levels, label) {
  if (length(s) == levels) return("")
  sprintf("%s{%s}", label, paste(sort(s), collapse = ","))
}

## Literals are written in alphabetical order of the condition, not in the
## order the columns happen to sit in. Otherwise the same term prints as
## A{0}*C{1} or C{1}*A{0} depending on how the data frame was assembled, and
## two runs of the same analysis cannot be compared as text.
##
## The ordinary collation order is used rather than a byte order: it is what
## readers expect of a condition named in their own language, and it never
## fails on a name outside ASCII. What it costs is that two machines whose
## locales collate differently can disagree about names differing only in
## case or accent -- the terms are the same either way.
minterm_to_str <- function(minterm, levels, labels) {
  parts <- vapply(seq_along(minterm), function(i) {
    set_to_str(minterm[[i]], levels[[i]], labels[[i]])
  }, character(1))
  keep <- nzchar(parts)
  if (!any(keep)) return("1")
  paste(parts[keep][order(unlist(labels)[keep])], collapse = "*")
}

## Rows covered by exactly one prime implicant identify essential terms.
calculate_essential_indexes <- function(elements) {
  all_cov <- unlist(lapply(elements, function(e) e$coverage), use.names = FALSE)
  if (length(all_cov) == 0L) return(integer(0))
  tab <- table(all_cov)
  as.integer(names(tab)[tab == 1L])
}

prime_implicants_on_dc <- function(ctx) {
  prepare_rows(ctx)
  if (nrow(ctx$table) == 0L) return(list())
  warn_many_levels(ctx$levels, ctx$labels)
  if (any(ctx$levels > MAX_LEVELS)) {
    stopf(paste0(
      "Condition(s) %s have more than %d levels, the width of the bit mask ",
      "the \"ON-DC\" reduction step uses. Use algorithm = \"ON-OFF\", which ",
      "has no such limit."),
      paste(sQuote(unlist(ctx$labels)[ctx$levels > MAX_LEVELS], q = FALSE),
            collapse = ", "), MAX_LEVELS)
  }

  table <- ctx$table
  column_number <- ncol(table)
  groups <- create_groups(table, column_number, ctx$cares,
                          ctx$outputcolumns, ctx$multi_output)

  found <- list()
  found_keys <- new.env(parent = emptyenv(), hash = TRUE)
  repeat {
    step <- reduction_step(groups, column_number, ctx$multi_output)
    for (el in step$implicants) {
      key <- element_key_mask(el$masks, el$coverage, el$tag, ctx$multi_output)
      if (!is.null(found_keys[[key]])) next
      assign(key, TRUE, envir = found_keys)
      found[[length(found) + 1L]] <- el
    }
    if (!step$reduction) break
    groups <- step$groups
  }

  elements <- eliminate_minterms(table, found, ctx$levels, ctx$multi_output)

  ## Translate configuration-space indices back to truth table rows.
  coverage_map <- stats::setNames(ctx$positive_cares, as.character(ctx$cares))
  map_cov <- function(cov) unname(coverage_map[as.character(cov)])

  if (ctx$multi_output) {
    return(lapply(elements, function(el) {
      raw <- mask_minterm_to_list(el$masks)
      new_implicant_mo(
        ctx,
        implicant = minterm_to_str(raw, ctx$levels, ctx$labels),
        raw_implicant = raw,
        coverage = sort(map_cov(el$coverage)),
        outputs = mask_to_values(el$tag) + 1L
      )
    }))
  }

  essential_indexes <- calculate_essential_indexes(elements)
  if (length(essential_indexes) > 0L) {
    is_essential <- vapply(
      elements,
      function(e) length(intersect(e$coverage, essential_indexes)) > 0L,
      logical(1)
    )
    all_essential <- sort(unique(unlist(
      lapply(elements[is_essential], function(e) e$coverage),
      use.names = FALSE
    )))
    useless <- vapply(seq_along(elements), function(i) {
      !is_essential[i] && is_subset(elements[[i]]$coverage, all_essential)
    }, logical(1))
    elements <- elements[!useless]
    is_essential <- is_essential[!useless]
  } else {
    is_essential <- rep(FALSE, length(elements))
  }

  lapply(seq_along(elements), function(i) {
    el <- elements[[i]]
    raw <- mask_minterm_to_list(el$masks)
    new_implicant(
      ctx,
      implicant = minterm_to_str(raw, ctx$levels, ctx$labels),
      raw_implicant = raw,
      coverage = sort(map_cov(el$coverage)),
      essential = is_essential[[i]]
    )
  })
}
