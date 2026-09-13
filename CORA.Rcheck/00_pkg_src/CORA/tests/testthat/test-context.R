test_that("the truth table aggregates cases and applies the inclusion cut", {
  df <- data.frame(
    ID = as.character(1:5),
    A = c(1, 1, 0, 1, 1), B = c(0, 1, 1, 1, 0),
    C = c(1, 1, 0, 1, 1), O = c(0, 0, 1, 1, 1)
  )
  ctx <- cora_context(df, "O", case_col = "ID", inc_score1 = 0.5)
  raw <- cora_truth_table(ctx, raw = TRUE)

  expect_equal(raw$A, c(0L, 1L, 1L))
  expect_equal(raw$B, c(1L, 0L, 1L))
  expect_equal(raw$C, c(0L, 1L, 1L))
  expect_equal(raw$n, c(1L, 2L, 2L))
  expect_equal(raw$Cases, c("3", "1,5", "2,4"))
  expect_equal(raw$Inc_O, c(1, 0.5, 0.5))
  expect_equal(raw$O, c(1L, 1L, 1L))
})

test_that("a non-binary outcome is rejected unless its values are declared", {
  df <- data.frame(a = c(1, 0, 0, 1), b = c(0, 1, 1, 0),
                   c = c(1, 1, 0, 1), o = c(0, 1, 0, 2))
  expect_error(cora_truth_table(cora_context(df, "o")), "Unsupported output")
})

test_that("declared outcome values are binarised before aggregation", {
  df <- data.frame(a = c(1, 0, 0, 1), b = c(0, 1, 1, 0),
                   c = c(1, 1, 0, 1), o = c(1, 1, 0, 2))

  tt1 <- cora_truth_table(cora_context(df, "o{1}"))
  expect_equal(unname(as.matrix(tt1)),
               matrix(c(0L, 1L, 0L, 0L,
                        0L, 1L, 1L, 1L,
                        1L, 0L, 1L, 0L), nrow = 3, byrow = TRUE))

  tt2 <- cora_truth_table(cora_context(df, "o{1,2}"))
  expect_equal(unname(as.matrix(tt2)),
               matrix(c(0L, 1L, 0L, 0L,
                        0L, 1L, 1L, 1L,
                        1L, 0L, 1L, 1L), nrow = 3, byrow = TRUE))
})

test_that("constant inputs are refused", {
  df <- data.frame(A = c(1, 1, 1, 1), B = c(1, 0, 0, 1), O = c(1, 0, 1, 1))
  expect_error(cora_prime_implicants(cora_context(df, "O")), "constants")
})

test_that("inc_score2 requires U", {
  df <- data.frame(A = c(1, 0, 1, 0), B = c(1, 0, 0, 1), O = c(1, 1, 0, 1))
  expect_error(
    cora_truth_table(cora_context(df, "O", inc_score2 = 0.5)),
    "U must be specified"
  )
})

test_that("a condition that skips zero is refused", {
  df <- data.frame(A = c(1, 1, 0, 0), B = c(2, 1, 2, 2),
                   C = c(0, 1, 1, 2), OUT = c(1, 0, 1, 1))
  expect_error(cora_truth_table(cora_context(df, "OUT")),
               "not coded from 0 upwards")
  expect_error(cora_truth_table(cora_context(df, "OUT")), "'B'")
  ## The message has to say what to do about it.
  expect_error(cora_truth_table(cora_context(df, "OUT")), "cora_recode")

  ok <- data.frame(A = c(1, 0, 1, 0), B = c(1, 0, 0, 1), OUT = c(1, 1, 0, 1))
  expect_no_error(cora_truth_table(cora_context(ok, "OUT")))
})

test_that("the message names every offending condition", {
  df <- data.frame(A = c(2, 1, 2, 1), B = c(3, 4, 3, 4),
                   C = c(0, 1, 1, 0), OUT = c(1, 0, 1, 1))
  expect_error(cora_truth_table(cora_context(df, "OUT")), "'A', 'B'")
})

test_that("data mining reports a coding problem instead of scoring zero", {
  ## The per-tuple loop treats a failed analysis as a tuple with no solution,
  ## so without its own check a coding problem would read as a row of zeros.
  df <- data.frame(A = c(1, 1, 0, 0), B = c(2, 1, 2, 2),
                   C = c(0, 1, 1, 2), OUT = c(1, 1, 0, 1))
  expect_error(cora_data_mining(df, "OUT", 2), "not coded from 0 upwards")
})

test_that("cora_recode maps a condition onto 0, 1, 2, ...", {
  df <- data.frame(A = c(2, 1, 2, 1), B = c(1, 2, 1, 2),
                   C = c(0, 1, 1, 0), OUT = c(1, 0, 1, 1))

  out <- cora_recode(df, c("A", "B"))
  expect_equal(out$A, c(1L, 0L, 1L, 0L))
  expect_equal(out$B, c(0L, 1L, 0L, 1L))
  expect_equal(out$C, df$C)       # already fine, left alone
  expect_equal(out$OUT, df$OUT)   # outcomes are never touched

  ## Left to itself it recodes exactly the columns that need it.
  expect_equal(cora_recode(df), out)

  ## A rating scale collected as 1-5 becomes 0-4, order preserved.
  expect_equal(cora_recode(data.frame(s = c(3, 1, 5, 1)), "s")$s,
               c(1L, 0L, 2L, 0L))

  ## Data that is already correct passes through untouched.
  ok <- data.frame(A = c(1, 0, 1, 0), B = c(0, 1, 2, 1))
  expect_equal(cora_recode(ok), ok)

  expect_error(cora_recode(df, "NOPE"), "not found")
})

test_that("recoding makes the analysis possible and the two algorithms agree", {
  df <- data.frame(A = c(1, 1, 0, 0), B = c(2, 1, 2, 2),
                   C = c(0, 1, 1, 2), OUT = c(1, 1, 0, 1))
  expect_error(cora_prime_implicants(cora_context(df, "OUT")))

  rc <- cora_recode(df, "B")
  label <- function(alg) {
    sort(vapply(cora_prime_implicants(cora_context(rc, "OUT", algorithm = alg)),
                function(p) p$implicant, character(1)))
  }
  expect_equal(label("ON-DC"), label("ON-OFF"))
})
