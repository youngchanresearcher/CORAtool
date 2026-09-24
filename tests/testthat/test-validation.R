test_that("max_depth restricts the call and not the context", {
  ctx <- cora_context(gross_carvin, "TORT", case_col = "Case",
                      algorithm = "ON-OFF")
  all_sums <- cora_irredundant_sums(ctx)
  expect_length(all_sums, 2L)
  expect_true(all(vapply(all_sums, function(s) length(s$system), 1L) == 3L))

  ## A restriction asked for after the unrestricted call must still apply ...
  expect_length(cora_irredundant_sums(ctx, max_depth = 1L), 0L)
  expect_length(cora_irredundant_sums(ctx, max_depth = 3L), 2L)
  ## ... and must not survive into the next call.
  expect_length(cora_irredundant_sums(ctx), 2L)

  ## The other order: a restricted call must not poison what follows it.
  fresh <- cora_context(gross_carvin, "TORT", case_col = "Case",
                        algorithm = "ON-OFF")
  expect_length(cora_irredundant_sums(fresh, max_depth = 1L), 0L)
  expect_length(cora_irredundant_sums(fresh), 2L)
  expect_true(all(c("M1", "M2") %in% names(cora_pi_details(fresh))))
  expect_equal(nrow(cora_solutions(fresh)), 2L)
  expect_silent(cora_system_details(fresh))

  ## Solutions keep the number they have in the unrestricted set.
  df <- data.frame(A = c(1, 0, 1, 0), B = c(1, 0, 0, 1),
                   C = c(0, 1, 1, 0), OUT = c(1, 1, 0, 1))
  sums <- cora_irredundant_sums(cora_context(df, "OUT"))
  expect_equal(vapply(sums, function(s) s$index, 1L), 1:2)

  expect_error(cora_irredundant_sums(ctx, max_depth = 0), "max_depth")
  expect_error(cora_irredundant_sums(ctx, max_depth = NA), "max_depth")
  expect_error(cora_irredundant_sums(ctx, max_depth = 2.5), "max_depth")
})

test_that("threshold arguments are checked rather than carried along", {
  df <- data.frame(A = c(1, 0, 1, 0), B = c(1, 0, 0, 1), O = c(1, 1, 0, 1))

  ## NA is the one that matters: unchecked it reaches a comparison that is
  ## neither TRUE nor FALSE and the run finishes on a threshold nobody set.
  expect_error(cora_context(df, "O", n_cut = NA), "n_cut")
  expect_error(cora_context(df, "O", inc_score1 = NA), "inc_score1")

  expect_error(cora_context(df, "O", n_cut = 0), "n_cut")
  expect_error(cora_context(df, "O", n_cut = -1), "n_cut")
  expect_error(cora_context(df, "O", n_cut = 1.5), "n_cut")
  expect_error(cora_context(df, "O", inc_score1 = -0.5), "inc_score1")
  expect_error(cora_context(df, "O", inc_score1 = 1.1), "inc_score1")
  expect_error(cora_context(df, "O", n_cut = c(1, 2)), "n_cut")

  ## inc_score2 is the lower edge of the band, so it cannot sit above the top.
  expect_error(
    cora_context(df, "O", inc_score1 = 0.4, inc_score2 = 0.9, U = 1),
    "inc_score2")
  expect_error(
    cora_context(df, "O", inc_score1 = 0.9, inc_score2 = 0.4, U = 2), "U")
  expect_error(
    cora_context(df, "O", inc_score1 = 0.9, inc_score2 = 0.4, U = NA), "U")

  expect_s3_class(cora_context(df, "O", n_cut = 2), "cora_context")
  expect_s3_class(cora_context(df, "O", inc_score1 = 0.75), "cora_context")
  expect_s3_class(
    cora_context(df, "O", inc_score1 = 0.9, inc_score2 = 0.4, U = 1),
    "cora_context")
})

test_that("columns are refused when their names cannot address them", {
  ## Columns are selected by name, so a duplicate name silently drops one of
  ## them, and a condition sharing the outcome's name reads the outcome from
  ## the wrong column.
  twice <- setNames(data.frame(c(1L, 0L, 1L, 0L), c(0L, 1L, 1L, 0L),
                               c(1L, 0L, 1L, 0L)), c("A", "A", "O"))
  expect_error(cora_prime_implicants(cora_context(twice, "O")), "Duplicated")

  clash <- setNames(data.frame(c(1L, 0L, 1L, 0L), c(0L, 1L, 1L, 0L),
                               c(1L, 0L, 1L, 0L)), c("O", "B", "O"))
  expect_error(cora_prime_implicants(cora_context(clash, "O")), "Duplicated")

  empty <- data.frame(A = integer(0), B = integer(0), O = integer(0))
  expect_error(cora_prime_implicants(cora_context(empty, "O")), "no rows")
})

test_that("a truth table emptied by n_cut yields no solution, not an error", {
  ## Every configuration appears once, so n_cut = 2 removes all of them. The
  ## single-outcome path returned an empty result; the multi-outcome one read
  ## the outcome tag off the first positive row and found none.
  df <- data.frame(A = c(0L, 1L, 2L, 0L, 1L, 2L),
                   B = c(0L, 1L, 0L, 1L, 0L, 1L),
                   O1 = c(1L, 0L, 1L, 0L, 1L, 0L),
                   O2 = c(0L, 1L, 1L, 0L, 0L, 1L))
  for (alg in c("ON-DC", "ON-OFF")) {
    one <- cora_context(df, "O1", n_cut = 2L, algorithm = alg)
    expect_equal(nrow(cora_truth_table(one)), 0L)
    expect_length(cora_prime_implicants(one), 0L)
    expect_length(cora_irredundant_sums(one), 0L)

    many <- cora_context(df, c("O1", "O2"), n_cut = 2L, algorithm = alg)
    expect_equal(nrow(cora_truth_table(many)), 0L)
    expect_length(cora_prime_implicants(many), 0L)
    expect_length(cora_irredundant_systems(many), 0L)
  }
})

test_that("a literal that cannot be drawn is refused, not approximated", {
  path <- tempfile(fileext = ".pdf")
  grDevices::pdf(path)
  on.exit({
    grDevices::dev.off()
    unlink(path)
  }, add = TRUE)

  ## Too large for an R integer: as.integer() would give NA and the literal
  ## would be drawn as though the condition had never been named.
  expect_error(cora_logigram("A{999999999999}<=>F"), "too large")

  ## A conjunction cannot give one condition two values.
  expect_error(cora_logigram("A{0}*A{1}<=>F"), "two values")
  expect_error(cora_logigram("a*A<=>F"), "two values")
  expect_error(cora_logigram("A{1}*B{1}*A{2}<=>F"), "two values")

  ## Repeating the same literal is not a contradiction.
  expect_silent(cora_logigram("A*A<=>F"))
  expect_silent(cora_logigram("A{1}*A{1}<=>F"))
  ## Nor is the same condition taking different values in different terms.
  expect_silent(cora_logigram("A{1}+A{0}<=>F"))
  expect_silent(cora_logigram("A*B+a*C<=>F"))
})

test_that("len_of_tuple is a whole number in range", {
  d <- data.frame(A = c(1, 0, 1, 0, 1, 0), B = c(1, 1, 0, 0, 1, 0),
                  C = c(0, 1, 1, 0, 1, 1), D = c(1, 1, 0, 1, 0, 0),
                  O = c(1, 1, 0, 0, 1, 1))
  ## 1.5 used to reach combn(), which truncates it to 1 and mines a tuple
  ## length nobody asked for.
  expect_error(cora_data_mining(d, "O", len_of_tuple = 1.5), "len_of_tuple")
  expect_error(cora_data_mining(d, "O", len_of_tuple = NA), "len_of_tuple")
  expect_error(cora_data_mining(d, "O", len_of_tuple = 0), "len_of_tuple")
  expect_error(cora_data_mining(d, "O", len_of_tuple = 5), "len_of_tuple")
  expect_equal(nrow(cora_data_mining(d, "O", len_of_tuple = 2)), 6L)

  ## The per-tuple loop treats a failed analysis as a tuple with no solution,
  ## so an unusable threshold has to be refused before that loop starts.
  expect_error(cora_data_mining(d, "O", len_of_tuple = 2, n_cut = NA), "n_cut")
  expect_error(cora_data_mining(d, "O", len_of_tuple = 2, inc_score1 = NA),
               "inc_score1")
})

test_that("reordering the data changes nothing but the reading order", {
  d <- data.frame(A = c(1, 0, 1, 0, 1, 0), B = c(1, 1, 0, 0, 1, 0),
                  C = c(0, 1, 1, 0, 1, 1), D = c(1, 1, 0, 1, 0, 0),
                  O = c(1, 1, 0, 0, 1, 1))
  literals <- function(x, ...) {
    sort(vapply(cora_prime_implicants(cora_context(x, "O", ...)),
                function(i) paste(sort(strsplit(sub("^#", "", i$implicant),
                                                "*", fixed = TRUE)[[1L]]),
                                  collapse = "*"), character(1)))
  }
  set.seed(9)
  shuffled_rows <- d[sample(nrow(d)), ]
  reordered_cols <- d[, c("C", "A", "D", "B", "O")]
  for (alg in c("ON-DC", "ON-OFF")) {
    expect_equal(literals(shuffled_rows, algorithm = alg),
                 literals(d, algorithm = alg))
    ## Literals inside a term print in column order, as they do in the Python
    ## implementation, so the terms are compared as sets of literals.
    expect_equal(literals(reordered_cols, algorithm = alg),
                 literals(d, algorithm = alg))
  }
})

test_that("a question that cannot mean what it says is refused", {
  d <- data.frame(ID = letters[1:6], A = c(1, 0, 1, 0, 1, 0),
                  B = c(1, 1, 0, 0, 1, 0), C = c(0, 1, 1, 0, 1, 1),
                  O = c(1, 1, 0, 0, 1, 1))

  ## An outcome used as one of its own conditions returns "#O{1}" — it
  ## explains itself perfectly and says nothing about anything else.
  expect_error(
    cora_truth_table(cora_context(d, "O", case_col = "ID",
                                  input_labels = c("A", "O"))),
    "explains only itself")
  expect_error(
    cora_truth_table(cora_context(d, "O", case_col = "ID",
                                  input_labels = c("A", "ID"))),
    "Case column")

  ## A case column naming nothing used to be ignored, losing the labels.
  expect_error(cora_truth_table(cora_context(d, "O", case_col = "NOPE")),
               "Case column not found")
  expect_error(cora_truth_table(cora_context(d, "O", case_col = c("ID", "A"))),
               "case_col")
  expect_error(cora_truth_table(cora_context(d, "O", case_col = 1)), "case_col")
  expect_error(
    cora_truth_table(cora_context(d, "O", case_col = "ID",
                                  input_labels = c("A", "A"))),
    "same column twice")

  expect_error(cora_context(d, ""), "output_labels")
  expect_error(cora_context(d, NA_character_), "output_labels")
  expect_error(cora_context(d, c("O", "O")), "same outcome twice")

  ## Mixing declared and undeclared outcomes used to report the declaration
  ## as a column name missing from the data.
  dm <- data.frame(A = c(0, 0, 1, 1, 2, 2), B = c(0, 1, 0, 1, 0, 1),
                   Y1 = c(1, 0, 1, 0, 1, 1), Y3 = c(0, 1, 2, 0, 1, 2))
  expect_error(cora_truth_table(cora_context(dm, c("Y1", "Y3{1,2}"))),
               "declared inconsistently")
  expect_equal(nrow(cora_truth_table(cora_context(dm, c("Y1{1}", "Y3{1,2}")))),
               6L)

  sol <- cora_irredundant_sums(cora_context(gross_carvin, "TORT",
                                            case_col = "Case",
                                            algorithm = "ON-OFF"))[[1L]]
  expect_error(cora_describe(sol, cov = 2), "cov")
  expect_error(cora_describe(sol, cov = NA), "cov")
})

test_that("the inclusion band puts the middle where U says", {
  ## Four cases per configuration, so an inclusion score of 0.5 lands inside
  ## a 0.4-0.9 band and U alone decides what it becomes.
  band <- data.frame(A = rep(c(0, 0, 1, 1), each = 4),
                     B = rep(c(0, 1, 0, 1), each = 4),
                     O = c(1, 1, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 1, 1, 0, 0))
  raw <- cora_truth_table(
    cora_context(band, "O", inc_score1 = 0.9, inc_score2 = 0.4, U = 1),
    raw = TRUE)
  expect_equal(raw$Inc_O, c(0.5, 1, 0, 0.5))

  band_at <- function(u) {
    cora_truth_table(cora_context(band, "O", inc_score1 = 0.9,
                                  inc_score2 = 0.4, U = u))$O
  }
  expect_equal(band_at(1L), c(1L, 1L, 0L, 1L))
  expect_equal(band_at(0L), c(0L, 1L, 0L, 0L))
  ## Without a band the single threshold decides, as U = 0 does here.
  expect_equal(cora_truth_table(cora_context(band, "O", inc_score1 = 0.9))$O,
               band_at(0L))
})

test_that("the Python comparison reports through print(), not while computing", {
  ## Building the object must write nothing; the report belongs to print().
  agree <- structure(
    list(r = NULL, python = NULL, agrees = TRUE,
         prime_implicants = compare_sets(c("#A{1}", "#B{0}"), c("#A{1}", "#B{0}")),
         solutions = compare_sets("#A{1}+#B{0}", "#A{1}+#B{0}")),
    class = "cora_comparison")
  expect_silent(agree$agrees)
  expect_output(print(agree), "prime implicants : agree")
  expect_output(vis <- withVisible(print(agree)))
  expect_false(vis$visible)

  ## When they part, the report says where, in both directions.
  differ <- agree
  differ$prime_implicants <- compare_sets(c("#A{1}", "#C{1}"), c("#A{1}", "#D{0}"))
  differ$agrees <- FALSE
  out <- format(differ)
  expect_true(any(grepl("prime implicants : DIFFER", out, fixed = TRUE)))
  expect_true(any(grepl("only in R      : #C{1}", out, fixed = TRUE)))
  expect_true(any(grepl("only in Python : #D{0}", out, fixed = TRUE)))
  expect_true(any(grepl("solutions        : agree", out, fixed = TRUE)))
})

test_that("nothing outside a print method writes to the console", {
  ## CRAN asks that information be returned as an object and printed on
  ## request. cat() and print() may appear only inside print.* methods.
  fns <- ls(asNamespace("CORAtool"), all.names = TRUE)
  offenders <- character(0)
  for (f in fns) {
    obj <- get(f, envir = asNamespace("CORAtool"))
    if (!is.function(obj) || startsWith(f, "print.")) next
    body_txt <- paste(deparse(body(obj)), collapse = "\n")
    if (grepl("\\b(cat|print|writeLines)\\(", body_txt)) offenders <- c(offenders, f)
  }
  expect_identical(offenders, character(0))
})
