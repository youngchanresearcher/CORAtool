## The classification cases are those of the LOGIGRAM test suite.

test_that("input expressions are classified correctly", {
  expect_equal(logigram_mode("A{1}<=>F"), "MULTI_VALUE")
  expect_equal(logigram_mode("A*b=F"), "BOOLEAN")
  expect_equal(logigram_mode("A{1}B{2}*C{3}<=>F"), "INVALID")
  expect_equal(logigram_mode("A{1}B{2}*C{3}=F"), "INVALID")
  expect_equal(logigram_mode("A{1}*B{2}+C{3}<=>F"), "MULTI_VALUE")
  expect_equal(logigram_mode("A*B+c<=>f"), "BOOLEAN")
  expect_equal(logigram_mode("A*B+c=f"), "BOOLEAN")
  expect_equal(logigram_mode("A*B+c*A<=>f"), "BOOLEAN")
  expect_equal(logigram_mode(c("A*b*C+C*D<=>F", "A*b*C+d*a<=>Y")),
               "MULTI_OUTPUT")
  expect_equal(logigram_mode(c("A*b*C+C*D=F", "A*b*C+d*a=Y")), "MULTI_OUTPUT")
  expect_equal(logigram_mode(c("A{1}+C{1}+C*D<=>F", "A{1}+C+D<=>Y")), "INVALID")
  expect_equal(logigram_mode(c("A{1}+C{1}<=>F", "A{1}+B{2}<=>Y")),
               "MV_MULTI_OUTPUT")
  expect_equal(logigram_mode("A*b"), "INVALID")
})

test_that("a binary expression parses into variables and implicants", {
  p <- logigram_parse("A*B+c*A+b<=>F")
  expect_equal(p$variables, c("A", "B", "C"))
  expect_equal(p$outputs, "F")
  expect_false(p$multi_value)
  expect_false(p$multi_output)
  expect_length(p$implicants, 3L)
  ## Single-literal implicants come first; they bypass the AND gates.
  expect_equal(sum(!is.na(p$implicants[[1L]]$values)), 1L)
  expect_setequal(
    vapply(p$implicants, function(i) paste(i$values, collapse = ","),
           character(1)),
    c("NA,0,NA", "1,1,NA", "1,NA,0")
  )
})

test_that("multi-value literals keep their values", {
  p <- logigram_parse("A{1}*B{2}+C{0}<=>F")
  expect_true(p$multi_value)
  expect_equal(p$variables, c("A", "B", "C"))
  expect_setequal(
    vapply(p$implicants, function(i) paste(i$values, collapse = ","),
           character(1)),
    c("NA,NA,0", "1,2,NA")
  )
})

test_that("an implicant shared by two functions is drawn once", {
  p <- logigram_parse(c("A{1}*B{2}+A{2}<=>F1", "A{1}+A{2}<=>F2"))
  expect_true(p$multi_output)
  expect_equal(p$outputs, c("F1", "F2"))
  shared <- Filter(function(i) identical(i$values, c(2L, NA_integer_)),
                   p$implicants)
  expect_length(shared, 1L)
  expect_equal(shared[[1L]]$outputs, c(1L, 2L))
})

test_that("prime notation converts to case notation", {
  p <- logigram_parse("a*b'+c<=>f", notation = "prime")
  expect_equal(p$variables, c("a", "b", "c"))
  expect_setequal(
    vapply(p$implicants, function(i) paste(i$values, collapse = ","),
           character(1)),
    c("NA,NA,1", "1,0,NA")
  )
})

test_that("an unsupported expression is refused", {
  expect_error(logigram_parse("A*b"), "Unsupported input")
})

test_that("a solution renders as a disjunctive normal form", {
  df <- data.frame(A = c(1, 0, 1, 0), B = c(1, 0, 0, 1),
                   C = c(0, 1, 1, 0), OUT = c(1, 1, 0, 1))
  sums <- cora_irredundant_sums(cora_context(df, "OUT"))
  expect_setequal(vapply(sums, cora_dnf, character(1)),
                  c("A{0}+B{1}<=>OUT", "A{0}+C{0}<=>OUT"))
})

test_that("a diagram can be drawn without error", {
  path <- tempfile(fileext = ".pdf")
  grDevices::pdf(path)
  on.exit({
    grDevices::dev.off()
    unlink(path)
  }, add = TRUE)
  expect_silent(cora_logigram("A*B+c*A+b<=>F"))
  expect_silent(cora_logigram(c("A{1}*B{2}+A{2}<=>F1", "A{1}+C{1}*B{2}<=>F2")))
})

test_that("a constant function is refused rather than drawn", {
  ## A tautological solution would otherwise be drawn with an input bus
  ## named "1", which reads as a condition that does not exist.
  expect_error(logigram_parse("1<=>F"), "constant function")
  expect_error(logigram_parse("0<=>F"), "constant function")
  expect_error(logigram_parse("A+1<=>F"), "constant function")
  expect_error(logigram_parse(c("A*B<=>F1", "1<=>F2")), "F2")

  df <- data.frame(A = c(1, 0, 1, 0), B = c(1, 0, 0, 1), OUT = c(1, 1, 1, 1))
  tautology <- cora_irredundant_sums(cora_context(df, "OUT"))[[1L]]
  expect_equal(cora_dnf(tautology), "1<=>OUT")
  expect_error(cora_logigram(tautology), "constant function")
})

test_that("the square bracket notation of the QCA package is read too", {
  square <- logigram_parse("A[1]*B[2]+C[0]<=>F")
  curly <- logigram_parse("A{1}*B{2}+C{0}<=>F")
  expect_equal(square, curly)
  expect_equal(logigram_mode("A[1]*B[2]+C[0]<=>F"), "MULTI_VALUE")
  expect_equal(logigram_mode(c("A[1]<=>F1", "B[2]<=>F2")), "MV_MULTI_OUTPUT")

  path <- tempfile(fileext = ".pdf")
  grDevices::pdf(path)
  on.exit({
    grDevices::dev.off()
    unlink(path)
  }, add = TRUE)
  expect_silent(cora_logigram("A[1]*B[2]+C[0]<=>F"))
})
