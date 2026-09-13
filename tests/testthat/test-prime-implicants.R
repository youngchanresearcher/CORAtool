## The expected values below were verified against the Python CORA package.

readme_data <- function() {
  data.frame(A = c(1, 0, 1, 0), B = c(1, 0, 0, 1),
             C = c(0, 1, 1, 0), OUT = c(1, 1, 0, 1))
}

test_that("the binary example yields the documented prime implicants", {
  for (alg in c("ON-DC", "ON-OFF")) {
    pis <- cora_prime_implicants(
      cora_context(readme_data(), "OUT", algorithm = alg)
    )
    expect_setequal(vapply(pis, function(p) p$implicant, character(1)),
                    c("B", "c", "#a"))
  }
})

test_that("essential prime implicants are marked", {
  pis <- cora_prime_implicants(cora_context(readme_data(), "OUT"))
  essential <- vapply(pis, function(p) p$essential, logical(1))
  labels <- vapply(pis, function(p) p$implicant, character(1))
  expect_equal(labels[essential], "#a")
})

test_that("coverage of a prime implicant indexes truth table rows", {
  ctx <- cora_context(readme_data(), "OUT")
  pis <- cora_prime_implicants(ctx)
  cov <- stats::setNames(lapply(pis, function(p) p$coverage),
                         vapply(pis, function(p) p$implicant, character(1)))
  expect_equal(sort(cov[["#a"]]), c(0L, 1L))
  expect_equal(sort(cov[["B"]]), c(1L, 3L))
  expect_equal(sort(cov[["c"]]), c(1L, 3L))
})

test_that("the prime implicant chart matches the coverage sets", {
  ctx <- cora_context(readme_data(), "OUT")
  chart <- cora_pi_chart(ctx)
  expect_equal(dim(chart), c(3L, 3L))
  expect_setequal(rownames(chart), c("B", "c", "#a"))
  expect_true(all(unlist(chart) %in% c(0L, 1L)))
  expect_equal(sum(chart["#a", ]), 2)
})

test_that("multi-value multi-outcome data gives the documented implicants", {
  df <- data.frame(A = c(1, 1, 0, 0), B = c(2, 1, 2, 2), C = c(0, 1, 1, 2),
                   D = c(1, 0, 0, 0), OUT1 = c(1, 2, 0, 1),
                   OUT2 = c(2, 0, 1, 1), OUT3 = c(1, 0, 2, 1))
  for (alg in c("ON-DC", "ON-OFF")) {
    ctx <- cora_context(df, c("OUT1{1,2}", "OUT2{1}", "OUT3{1,0}"),
                        algorithm = alg)
    pis <- cora_prime_implicants(ctx)
    expect_setequal(
      vapply(pis, function(p) p$implicant, character(1)),
      c("C{2}", "A{1}", "B{1}", "D{1}", "C{0}", "B{2}*C{1}", "A{0}",
        "B{2}*D{0}")
    )
  }
})

test_that("the two algorithms agree on the bundled data sets", {
  cases <- list(
    list(data = gross_carvin, out = "TORT", extra = list(case_col = "Case")),
    list(data = swiss_minaret, out = c("X", "M"), extra = list())
  )
  for (case in cases) {
    label <- function(ctx) {
      sort(vapply(cora_prime_implicants(ctx), function(p) {
        if (ctx$multi_output) {
          paste0(p$implicant, "|", paste(sort(p$outputs), collapse = ","))
        } else {
          p$implicant
        }
      }, character(1)))
    }
    a <- do.call(cora_context, c(list(case$data, case$out,
                                      algorithm = "ON-DC"), case$extra))
    b <- do.call(cora_context, c(list(case$data, case$out,
                                      algorithm = "ON-OFF"), case$extra))
    expect_equal(label(a), label(b))
  }
})
