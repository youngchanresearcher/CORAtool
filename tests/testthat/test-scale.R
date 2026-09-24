## The four behaviours chosen for 0.1.1 when an analysis gets large.

test_that("a bounded search returns exactly what an exhaustive one would", {
  ## Pruning during Petrick's method is exact rather than approximate: a
  ## product never loses an implicant as multiplication continues, so nothing
  ## dropped could have come back under the bound.
  random_data <- function(seed, outcomes = 1L) {
    set.seed(seed)
    repeat {
      nc <- sample(3:4, 1L)
      nr <- sample(8:14, 1L)
      lev <- sample(2:3, nc, replace = TRUE)
      d <- as.data.frame(lapply(seq_len(nc), function(j) {
        sample(0:(lev[[j]] - 1L), nr, replace = TRUE)
      }))
      names(d) <- paste0("C", seq_len(nc))
      ok <- all(vapply(d, function(v) {
        u <- sort(unique(v))
        length(u) > 1L && identical(u, seq.int(0L, length(u) - 1L))
      }, logical(1)))
      if (!ok) next
      for (k in seq_len(outcomes)) d[[paste0("O", k)]] <- sample(0:1, nr, TRUE)
      outs <- paste0("O", seq_len(outcomes))
      if (any(vapply(outs, function(o) length(unique(d[[o]])) == 1L,
                     logical(1)))) next
      return(list(data = d, outputs = outs))
    }
  }
  terms_of <- function(sols, multi) {
    sort(vapply(sols, function(s) {
      impl <- if (multi) system_unique_implicants(s) else s$system
      paste(sort(vapply(impl, function(i) i$implicant, character(1))),
            collapse = "+")
    }, character(1)))
  }

  for (seed in 1:15) {
    for (outcomes in 1:2) {
      spec <- random_data(seed, outcomes)
      multi <- outcomes > 1L
      solve <- function(...) {
        ctx <- cora_context(spec$data, spec$outputs, algorithm = "ON-OFF")
        if (multi) cora_irredundant_systems(ctx, ...)
        else cora_irredundant_sums(ctx, ...)
      }
      full <- solve()
      if (length(full) == 0L) next
      sizes <- vapply(full, function(s) {
        length(if (multi) system_unique_implicants(s) else s$system)
      }, integer(1))
      for (md in unique(c(1L, min(sizes), max(sizes)))) {
        expect_equal(terms_of(solve(max_depth = md, search = "bounded"), multi),
                     terms_of(solve(max_depth = md, search = "exhaustive"),
                              multi))
      }
    }
  }
})

test_that("a bound that no outcome can meet leaves no system standing", {
  ## Here O needs two prime implicants and O2 needs one. Bounding each
  ## outcome's own chart at one used to leave O with no sum, drop it, and
  ## return a "system" that explained O2 alone and O not at all.
  d <- data.frame(
    C1 = c(0L, 1L, 1L, 0L, 0L, 1L, 0L, 0L, 1L, 0L),
    C2 = c(2L, 0L, 2L, 2L, 1L, 2L, 1L, 2L, 2L, 0L),
    C3 = c(1L, 1L, 1L, 0L, 0L, 1L, 1L, 1L, 1L, 1L),
    O  = c(1L, 1L, 1L, 0L, 0L, 0L, 1L, 0L, 1L, 0L),
    O2 = c(1L, 0L, 1L, 1L, 0L, 1L, 0L, 1L, 0L, 0L))

  solve <- function(...) {
    cora_irredundant_systems(cora_context(d, c("O", "O2"),
                                          algorithm = "ON-DC"), ...)
  }
  expect_length(solve(max_depth = 1L, search = "bounded"), 0L)
  expect_length(solve(max_depth = 2L, search = "bounded"), 0L)
  expect_length(solve(max_depth = 3L, search = "bounded"), 1L)
  expect_length(solve(), 1L)

  ## Whatever a bounded search does return still explains every outcome.
  for (md in 1:4) {
    for (sys in solve(max_depth = md, search = "bounded")) {
      expect_true(all(lengths(sys$system_multiple) > 0L))
      expect_lte(length(system_unique_implicants(sys)), md)
    }
  }
})

test_that("literals are written in alphabetical order of the condition", {
  d <- data.frame(A = c(1, 0, 1, 0, 1, 0), B = c(1, 1, 0, 0, 1, 0),
                  C = c(0, 1, 1, 0, 1, 1), D = c(1, 1, 0, 1, 0, 0),
                  O = c(1, 1, 0, 0, 1, 1))
  terms <- function(x, ...) {
    sort(vapply(cora_prime_implicants(cora_context(x, "O", ...)),
                function(i) i$implicant, character(1)))
  }
  for (alg in c("ON-DC", "ON-OFF")) {
    straight <- terms(d, algorithm = alg)
    ## Same data, columns in a different order: the strings must match, not
    ## just the sets of literals.
    expect_equal(terms(d[, c("C", "A", "D", "B", "O")], algorithm = alg),
                 straight)
    expect_equal(terms(d[, c("D", "C", "B", "A", "O")], algorithm = alg),
                 straight)
    expect_true(all(grepl("^#?A", straight[grepl("A\\{", straight)])))
  }

  ## Sorting must not assume the names are ASCII. A byte-order sort refuses a
  ## name outside it when the session locale is not UTF-8.
  cjk <- stats::setNames(
    data.frame(c(1, 0, 1, 0), c(1, 1, 0, 0), c(1, 1, 0, 1)),
    c("\u689d\u4ef6\u4e59", "\u689d\u4ef6\u7532", "O"))
  expect_silent(cora_prime_implicants(cora_context(cjk, "O")))
  mixed <- data.frame(b = c(1, 0, 1, 0), A = c(1, 1, 0, 0), c = c(0, 1, 1, 0),
                      B = c(1, 0, 0, 1), O = c(1, 1, 0, 1))
  expect_silent(cora_prime_implicants(cora_context(mixed, "O")))
})

test_that("a condition with many levels warns before ON-DC is asked to run", {
  wide <- data.frame(A = 0:14, B = rep(0:1, length.out = 15L))
  wide$O <- as.integer(wide$A > 12L)
  expect_warning(cora_prime_implicants(cora_context(wide, "O")), "ON-OFF")
  ## ON-OFF is the way out, so it must not warn about the same data.
  expect_silent(
    cora_prime_implicants(cora_context(wide, "O", algorithm = "ON-OFF")))
  ## A condition inside the range says nothing.
  narrow <- data.frame(A = 0:9, B = rep(0:1, length.out = 10L))
  narrow$O <- as.integer(narrow$A > 7L)
  expect_silent(cora_prime_implicants(cora_context(narrow, "O")))
})

test_that("past the mask width ON-DC refuses by name and ON-OFF still answers", {
  ## 31 levels is one more than the mask can hold. ON-DC has to say so, and
  ## has to say which condition and what to do instead.
  over <- data.frame(A = 0:30, B = rep(0:1, length.out = 31L))
  over$O <- as.integer(over$A > 28L)
  expect_error(
    suppressWarnings(cora_prime_implicants(cora_context(over, "O"))),
    "'A'.*30 levels.*ON-OFF")
  ## ON-OFF works from the observed rows, so the width of the mask is not its
  ## problem at any size, and the answer is still the right one.
  wide <- data.frame(A = 0:39, B = rep(0:1, length.out = 40L))
  wide$O <- as.integer(wide$A > 37L)
  pis <- cora_prime_implicants(cora_context(wide, "O", algorithm = "ON-OFF"))
  expect_setequal(vapply(pis, function(i) i$implicant, character(1)),
                  c("#A{38}", "#A{39}"))
})

test_that("the summary tables say what they left out", {
  df <- data.frame(A = c(1, 0, 1, 0), B = c(1, 0, 0, 1),
                   C = c(0, 1, 1, 0), OUT = c(1, 1, 0, 1))
  ctx <- cora_context(df, "OUT")
  ## Two solutions is not many, so nothing is said and nothing is dropped.
  expect_silent(cora_pi_details(ctx))
  expect_equal(nrow(cora_solutions(ctx)), 2L)
  ## Asked to show one, it shows one and says so.
  expect_message(out <- cora_solutions(cora_context(df, "OUT"),
                                       max_solutions = 1L), "2 solutions")
  expect_equal(nrow(out), 1L)
  expect_message(det <- cora_pi_details(cora_context(df, "OUT"),
                                        max_solutions = 1L), "2 solutions")
  expect_equal(ncol(det), 4L)
  expect_error(cora_solutions(ctx, max_solutions = 0), "max_solutions")
  expect_error(cora_solutions(ctx, max_solutions = NA), "max_solutions")
  ## Inf asks for the lot.
  expect_silent(cora_solutions(cora_context(df, "OUT"), max_solutions = Inf))
})
