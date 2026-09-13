readme_data <- function() {
  data.frame(A = c(1, 0, 1, 0), B = c(1, 0, 0, 1),
             C = c(0, 1, 1, 0), OUT = c(1, 1, 0, 1))
}

test_that("the binary example yields the documented irredundant sums", {
  sums <- cora_irredundant_sums(cora_context(readme_data(), "OUT"))
  expect_length(sums, 2L)
  expect_setequal(
    vapply(sums, function(s) {
      paste(sort(vapply(s$system, function(i) i$implicant, character(1))),
            collapse = "+")
    }, character(1)),
    c("#a+B", "#a+c")
  )
})

test_that("essential prime implicants come first inside a solution", {
  sums <- cora_irredundant_sums(cora_context(readme_data(), "OUT"))
  for (s in sums) expect_equal(s$system[[1L]]$implicant, "#a")
})

test_that("solution and prime implicant scores match the reference", {
  ctx <- cora_context(readme_data(), "OUT")
  details <- cora_pi_details(ctx)
  expect_equal(sort(details$Cov.r), rep(0.67, 3))
  expect_equal(sort(details$Inc.), rep(1, 3))

  overview <- cora_system_details(ctx)
  expect_equal(overview$Cov., 1)
  expect_equal(overview$Inc., 1)
})

test_that("the solution table marks the prime implicants of each solution", {
  ctx <- cora_context(readme_data(), "OUT")
  sols <- cora_solutions(ctx)
  expect_equal(nrow(sols), 2L)
  expect_equal(unname(rowSums(sols)), c(2L, 2L))
  expect_equal(unname(sols[["#a"]]), c(1L, 1L))
})

test_that("single and multi outcome solvers refuse the wrong mode", {
  single <- cora_context(readme_data(), "OUT")
  expect_error(cora_irredundant_systems(single), "single-output")

  multi <- cora_context(swiss_minaret, c("X", "M"), algorithm = "ON-OFF")
  expect_error(cora_irredundant_sums(multi), "multi-output")
})

test_that("multi-outcome systems cover every outcome", {
  df <- data.frame(A = c(1, 1, 0, 0), B = c(2, 1, 2, 2), C = c(0, 1, 1, 2),
                   D = c(1, 0, 0, 0), OUT1 = c(1, 2, 0, 1),
                   OUT2 = c(2, 0, 1, 1), OUT3 = c(1, 0, 2, 1))
  ctx <- cora_context(df, c("OUT1{1,2}", "OUT2{1}", "OUT3{1,0}"),
                      algorithm = "ON-OFF")
  systems <- suppressWarnings(cora_irredundant_systems(ctx))
  expect_setequal(
    vapply(systems, function(s) {
      paste(vapply(s$system_multiple, function(per_out) {
        paste(sort(vapply(per_out, function(i) i$implicant, character(1))),
              collapse = "+")
      }, character(1)), collapse = "/")
    }, character(1)),
    c("A{1}/B{2}*D{0}/A{1}", "B{1}/B{2}*D{0}/B{1}")
  )
  for (s in systems) {
    expect_equal(cora_coverage_score(s), 0.75)
    expect_equal(cora_inclusion_score(s), 1)
  }
})

test_that("solutions render as sufficiency statements", {
  sums <- cora_irredundant_sums(cora_context(readme_data(), "OUT"))
  expect_setequal(vapply(sums, cora_describe, character(1)),
                  c("#a + B <=> OUT", "#a + c <=> OUT"))
})
