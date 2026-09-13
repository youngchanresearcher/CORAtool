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
