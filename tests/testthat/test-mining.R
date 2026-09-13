test_that("data mining scores every tuple of the documented example", {
  data <- data.frame(A = c(1, 1, 1, 0), B = c(0, 1, 0, 1),
                     C = c(1, 1, 0, 0), O = c(0, 1, 0, 1))
  res <- cora_data_mining(data, "O", len_of_tuple = 2)

  expect_equal(res$Combination, c("A, B", "A, C", "B, C"))
  expect_equal(res$Nr_of_systems, c(1L, 1L, 1L))
  expect_equal(res$Inc_score, c(1, 1, 1))
  expect_equal(res$Cov_score, c(1, 0.5, 1))
  expect_equal(res$Score, c(1, 0.5, 1))
})

test_that("both algorithms mine the same tuples", {
  data <- data.frame(A = c(1, 1, 0, 0), B = c(0, 0, 1, 0),
                     C = c(1, 0, 0, 1), O = c(0, 0, 1, 1))
  expect_equal(cora_data_mining(data, "O", 3, algorithm = "ON-DC"),
               cora_data_mining(data, "O", 3, algorithm = "ON-OFF"))
})

test_that("the automatic search widens the tuple until it finds a solution", {
  data <- data.frame(A = c(1, 0, 0, 1), B = c(1, 1, 0, 0),
                     C = c(0, 1, 1, 0), Z = c(0, 0, 0, 1))
  res <- cora_data_mining(data, "Z", 1, automatic = TRUE)
  expect_true(sum(res$Nr_of_systems) > 0L)
  expect_true(all(nchar(res$Combination) > 1L))
})

test_that("an out-of-range tuple length is refused", {
  data <- data.frame(A = c(1, 0), B = c(0, 1), O = c(1, 0))
  expect_error(cora_data_mining(data, "O", 5), "must lie between")
})

test_that("a tuple whose only solution is a tautology scores zero", {
  ## Every observed configuration of A and B shows the outcome, so the pair
  ## explains nothing and must not be ranked alongside a real solution.
  data <- data.frame(A = c(1, 1, 0, 0), B = c(2, 1, 2, 2),
                     C = c(0, 1, 1, 2), OUT = c(1, 1, 0, 1))
  res <- cora_data_mining(data, "OUT", len_of_tuple = 2, inc_score1 = 0.5)

  ab <- res[res$Combination == "A, B", ]
  expect_equal(ab$Nr_of_systems, 0L)
  expect_equal(ab$Score, 0)

  ac <- res[res$Combination == "A, C", ]
  expect_equal(ac$Nr_of_systems, 1L)
  expect_equal(ac$Score, 1)
})
