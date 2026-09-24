## Both cases are taken from the test suite of the reference implementation
## and were checked against its native Petrick solver.

test_that("Petrick's method finds the known irredundant sums", {
  coverages <- list(c(0, 1), c(0, 2), c(1, 5), c(2, 6), c(5, 7), c(6, 7))
  labels <- c("K", "L", "M", "N", "P", "Q")
  res <- cora_petrick(coverages)

  expect_equal(res$essential, integer(0))
  expect_setequal(
    vapply(res$sums, function(s) paste(labels[s], collapse = ""), character(1)),
    c("KLPQ", "KMNQ", "KNP", "LMNP", "LMQ")
  )
})

test_that("Petrick's method scales to a larger chart", {
  coverages <- list(
    8, 5, c(5, 7), 2, c(2, 7), c(2, 5, 7), 1, c(1, 5), c(1, 2),
    c(1, 2, 5, 7), 0, c(0, 8), c(0, 5), c(0, 2), c(0, 1, 5),
    c(0, 1, 5, 7), c(0, 1, 2, 5)
  )
  expect_equal(length(cora_petrick(coverages)$sums), 76L)
})

test_that("a row covered by a single implicant makes it essential", {
  res <- cora_petrick(list(c(1, 2), c(2, 3), c(3, 4)))
  expect_equal(res$essential, c(1L, 3L))
  expect_equal(res$sums, list(c(1L, 3L)))
})

test_that("interchangeable implicants are expanded into separate solutions", {
  res <- cora_petrick(list(c(1, 2), c(1, 2)))
  expect_setequal(vapply(res$sums, paste, character(1), collapse = ","),
                  c("1", "2"))
  expect_equal(res$essential, integer(0))
})

test_that("an empty chart yields no solutions", {
  res <- cora_petrick(list())
  expect_equal(res$sums, list())
  expect_equal(res$essential, integer(0))
})
