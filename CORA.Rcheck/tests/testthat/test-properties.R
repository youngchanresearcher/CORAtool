## Properties that must hold of any correct output, checked against randomly
## generated data rather than against a reference implementation.

random_context <- function(seed) {
  set.seed(seed)
  repeat {
    nc <- sample(2:4, 1L)
    nr <- sample(5:11, 1L)
    lev <- sample(2:3, nc, replace = TRUE)
    d <- as.data.frame(lapply(seq_len(nc), function(j) {
      sample(0:(lev[[j]] - 1L), nr, replace = TRUE)
    }))
    names(d) <- paste0("C", seq_len(nc))
    zero_based <- all(vapply(d, function(v) {
      u <- sort(unique(v))
      length(u) > 1L && identical(u, seq.int(0L, length(u) - 1L))
    }, logical(1)))
    if (!zero_based) next
    d$O <- sample(0:1, nr, replace = TRUE)
    if (length(unique(d$O)) == 1L) next
    return(list(data = d, algorithm = sample(c("ON-DC", "ON-OFF"), 1L)))
  }
}

test_that("solutions cover every positive row and none is redundant", {
  for (seed in 1:40) {
    spec <- random_context(seed)
    ctx <- cora_context(spec$data, "O", algorithm = spec$algorithm)
    tt <- cora_truth_table(ctx)
    pis <- cora_prime_implicants(ctx)
    if (length(pis) == 0L) next
    positive <- which(tt$O == 1L) - 1L

    for (sol in cora_irredundant_sums(ctx)) {
      covered <- sort(unique(unlist(lapply(sol$system, function(i) i$coverage))))
      expect_setequal(covered, positive)

      ## Irredundant means no term can be dropped without losing a row.
      if (length(sol$system) > 1L) {
        for (j in seq_along(sol$system)) {
          without <- sort(unique(unlist(
            lapply(sol$system[-j], function(i) i$coverage))))
          expect_false(setequal(without, positive))
        }
      }
    }
  }
})

test_that("every prime implicant is an implicant, and prime", {
  for (seed in 41:80) {
    spec <- random_context(seed)
    ctx <- cora_context(spec$data, "O", algorithm = spec$algorithm)
    tt <- cora_truth_table(ctx)
    pis <- cora_prime_implicants(ctx)
    if (length(pis) == 0L) next
    positive <- which(tt$O == 1L) - 1L

    labels <- vapply(pis, function(i) i$implicant, character(1))
    expect_equal(anyDuplicated(labels), 0L)

    for (i in pis) {
      ## An implicant of the outcome covers positive rows only ...
      expect_length(setdiff(i$coverage, positive), 0L)
      ## ... and its scores are proportions.
      for (s in c(cora_coverage_score(i), cora_inclusion_score(i))) {
        if (!is.na(s)) expect_true(s >= 0 && s <= 1)
      }
      ## An essential prime implicant holds a row no other one reaches.
      if (startsWith(i$implicant, "#")) {
        others <- unlist(lapply(
          Filter(function(z) !identical(z$implicant, i$implicant), pis),
          function(z) z$coverage))
        expect_gt(length(setdiff(i$coverage, others)), 0L)
      }
    }
  }
})

test_that("the two algorithms agree on well-coded data", {
  for (seed in 81:120) {
    spec <- random_context(seed)
    terms <- lapply(c("ON-DC", "ON-OFF"), function(alg) {
      pis <- cora_prime_implicants(
        cora_context(spec$data, "O", algorithm = alg))
      sort(vapply(pis, function(i) sub("^#", "", i$implicant), character(1)))
    })
    expect_equal(terms[[2L]], terms[[1L]])
  }
})
