## ---------------------------------------------------------------------------
## CORA 0.1.1 acceptance test
##
## Run this after installing the package. It exercises every exported
## function, checks the behaviours introduced in 0.1.1, and confirms that the
## inputs that should be refused are refused. Nothing here needs Python.
##
##   Rscript tools/acceptance.R
## or, in an R session:
##   source("tools/acceptance.R")
## ---------------------------------------------------------------------------

library(CORA)

PASS <- 0L; FAIL <- 0L; FAILED <- character(0)

## Each check states what should happen: "value" = must succeed, "error" =
## must be refused, "warning" = must warn, "message" = must say something.
chk <- function(label, expr, expect = "value", pattern = NULL) {
  msgs <- character(0); warns <- character(0)
  res <- withCallingHandlers(
    tryCatch(list(v = force(expr), err = NULL),
             error = function(e) list(v = NULL, err = conditionMessage(e))),
    warning = function(w) {
      warns <<- c(warns, conditionMessage(w)); invokeRestart("muffleWarning")
    },
    message = function(m) {
      msgs <<- c(msgs, conditionMessage(m)); invokeRestart("muffleMessage")
    })

  got <- if (!is.null(res$err)) "error"
         else if (length(warns)) "warning"
         else if (length(msgs)) "message"
         else "value"
  text <- c(res$err, warns, msgs)

  ok <- switch(expect,
    value   = is.null(res$err) && !length(warns),
    error   = !is.null(res$err),
    warning = length(warns) > 0L,
    message = length(msgs) > 0L,
    any     = TRUE)
  if (ok && !is.null(pattern)) {
    ok <- any(grepl(pattern, text)) ||
          (expect == "value" && is.character(res$v) &&
             any(grepl(pattern, res$v)))
  }
  if (ok) PASS <<- PASS + 1L else { FAIL <<- FAIL + 1L; FAILED <<- c(FAILED, label) }

  detail <- if (length(text)) substr(gsub("[\r\n]+", " | ", text[[1]]), 1, 72)
            else paste(utils::capture.output(
              utils::str(res$v, max.level = 1, give.attr = FALSE))[1],
              collapse = "")
  cat(sprintf("%-4s %-56s %s\n", if (ok) "ok" else "FAIL", label,
              substr(trimws(detail), 1, 72)))
  invisible(res$v)
}

hdr <- function(x) cat("\n== ", x, " ", strrep("=", max(0, 60 - nchar(x))),
                       "\n", sep = "")

## ---------------------------------------------------------------------------
hdr("installation")

chk("package version is 0.1.1",
    { stopifnot(as.character(packageVersion("CORA")) == "0.1.1"); TRUE })
chk("both manuals are installed",
    { f <- list.files(system.file("docs", package = "CORA"))
      stopifnot(all(c("manual_en.md", "manual_zh-TW.md") %in% f)); f })
chk("the vignette is registered",
    { v <- vignette(package = "CORA")$results
      stopifnot("cora" %in% v[, "Item"]); v[, "Item"] })
chk("citation() reports the installed version",
    { n <- citation("CORA")[[1]]$note
      stopifnot(grepl("0.1.1", n)); n })
chk("the runnable tour ships with the package",
    { f <- system.file("examples", "getting-started.R", package = "CORA")
      stopifnot(nzchar(f)); basename(f) })

## ---------------------------------------------------------------------------
hdr("a binary analysis, end to end")

df <- data.frame(A   = c(1, 0, 1, 0),
                 B   = c(1, 0, 0, 1),
                 C   = c(0, 1, 1, 0),
                 OUT = c(1, 1, 0, 1))
ctx <- cora_context(df, output_labels = "OUT")

chk("truth table has 4 rows", { stopifnot(nrow(cora_truth_table(ctx)) == 4L); TRUE })
chk("3 prime implicants, one of them essential",
    { p <- vapply(cora_prime_implicants(ctx), function(i) i$implicant, "")
      stopifnot(length(p) == 3L, sum(startsWith(p, "#")) == 1L); p })
chk("the PI chart is 3 x 3", { stopifnot(identical(dim(cora_pi_chart(ctx)), c(3L, 3L))); TRUE })
chk("2 irredundant solutions (model ambiguity)",
    { stopifnot(length(cora_irredundant_sums(ctx)) == 2L); TRUE })
chk("pi_details carries M1 and M2",
    { d <- cora_pi_details(ctx)
      stopifnot(all(c("PI", "Cov.r", "Inc.", "M1", "M2") %in% names(d))); names(d) })
chk("system_details is one row", { stopifnot(nrow(cora_system_details(ctx)) == 1L); TRUE })
chk("cora_solutions is one row per solution",
    { stopifnot(nrow(cora_solutions(ctx)) == 2L); TRUE })
chk("cora_describe returns a relation",
    cora_describe(cora_irredundant_sums(ctx)[[1]]), pattern = "<=>|=>|<=")
chk("cora_dnf round-trips through the parser",
    { d <- cora_dnf(cora_irredundant_sums(ctx)[[1]])
      grDevices::pdf(tempfile()); on.exit(grDevices::dev.off(), add = TRUE)
      cora_logigram(d); d })
chk("scores are proportions",
    { s <- unlist(lapply(cora_prime_implicants(ctx),
             function(i) c(cora_coverage_score(i), cora_inclusion_score(i))))
      stopifnot(all(s >= 0 & s <= 1)); range(s) })

## ---------------------------------------------------------------------------
hdr("multi-value conditions and complex effects")

tort <- cora_context(gross_carvin, "TORT", case_col = "Case",
                     algorithm = "ON-OFF")
chk("gross_carvin gives 8 prime implicants",
    { stopifnot(length(cora_prime_implicants(tort)) == 8L); TRUE })
chk("gross_carvin gives 2 solutions, Cov. = Inc. = 1",
    { s <- cora_irredundant_sums(tort); d <- cora_system_details(tort)
      stopifnot(length(s) == 2L, d[[1]] == 1, d[[2]] == 1); TRUE })

mn <- cora_context(swiss_minaret, c("X", "M"), algorithm = "ON-OFF")
chk("swiss_minaret: a system per outcome",
    { sys <- cora_irredundant_systems(mn)[[1]]
      stopifnot(length(sys$system_multiple) == 2L,
                all(lengths(sys$system_multiple) > 0L)); TRUE })
chk("irredundant_sums is refused in multi-output mode",
    cora_irredundant_sums(mn), "error", "multi-output")
chk("irredundant_systems is refused in single-output mode",
    cora_irredundant_systems(ctx), "error", "single-output")

chk("bergschlosser, three outcomes, runs",
    { b <- cora_context(bergschlosser, c("AUTH", "DEM", "PRAET"),
             input_labels = c("AGRPOP","PARCL","APROG","PS","RQ","LRC"),
             case_col = "Case", inc_score1 = 0.6, algorithm = "ON-OFF")
      length(cora_prime_implicants(b)) })

## ---------------------------------------------------------------------------
hdr("the two algorithms agree on well-coded data")

agree <- function(data, outs, ...) {
  terms <- lapply(c("ON-DC", "ON-OFF"), function(a) {
    sort(vapply(cora_prime_implicants(
      cora_context(data, outs, algorithm = a, ...)),
      function(i) sub("^#", "", i$implicant), character(1)))
  })
  stopifnot(identical(terms[[1]], terms[[2]]))
  length(terms[[1]])
}
chk("binary example: ON-DC == ON-OFF", agree(df, "OUT"))
chk("mccluskey (two outcomes): ON-DC == ON-OFF", agree(mccluskey, c("F1", "F2")))
chk("swiss_minaret: ON-DC == ON-OFF", agree(swiss_minaret, c("X", "M")))
chk("40 random data sets: ON-DC == ON-OFF", {
  n <- 0L
  for (seed in 1:40) {
    set.seed(seed)
    repeat {
      nc <- sample(2:4, 1L); nr <- sample(6:12, 1L)
      d <- as.data.frame(lapply(seq_len(nc),
             function(j) sample(0:sample(1:2, 1L), nr, TRUE)))
      names(d) <- paste0("C", seq_len(nc))
      okc <- all(vapply(d, function(v) {
        u <- sort(unique(v))
        length(u) > 1L && identical(u, seq.int(0L, length(u) - 1L))
      }, logical(1)))
      if (!okc) next
      d$O <- sample(0:1, nr, TRUE)
      if (length(unique(d$O)) > 1L) break
    }
    agree(d, "O"); n <- n + 1L
  }
  sprintf("%d data sets agreed", n)
})

## ---------------------------------------------------------------------------
hdr("max_depth: bounded search, and no cache poisoning")

fresh <- function() cora_context(gross_carvin, "TORT", case_col = "Case",
                                 algorithm = "ON-OFF")
chk("solutions here need 3 prime implicants each",
    { s <- cora_irredundant_sums(fresh())
      stopifnot(all(vapply(s, function(x) length(x$system), 1L) == 3L)); TRUE })
chk("max_depth = 1 returns nothing",
    { stopifnot(length(cora_irredundant_sums(fresh(), max_depth = 1)) == 0L); TRUE })
chk("max_depth = 3 returns both",
    { stopifnot(length(cora_irredundant_sums(fresh(), max_depth = 3)) == 2L); TRUE })
chk("a restricted call does not poison the context", {
  c1 <- fresh()
  stopifnot(length(cora_irredundant_sums(c1, max_depth = 1)) == 0L)
  stopifnot(length(cora_irredundant_sums(c1)) == 2L)        # still all of them
  stopifnot(all(c("M1", "M2") %in% names(cora_pi_details(c1))))
  stopifnot(nrow(cora_solutions(c1)) == 2L)
  TRUE
})
chk("an unrestricted call first does not disable max_depth", {
  c2 <- fresh()
  stopifnot(length(cora_irredundant_sums(c2)) == 2L)
  stopifnot(length(cora_irredundant_sums(c2, max_depth = 1)) == 0L)
  TRUE
})
chk("bounded and exhaustive return the same solutions", {
  key <- function(s) sort(vapply(s, function(x)
    paste(sort(vapply(x$system, function(i) i$implicant, "")), collapse = "+"), ""))
  for (md in 1:4)
    stopifnot(identical(
      key(cora_irredundant_sums(fresh(), max_depth = md, search = "bounded")),
      key(cora_irredundant_sums(fresh(), max_depth = md, search = "exhaustive"))))
  TRUE
})
chk("a bound is checked", cora_irredundant_sums(fresh(), max_depth = 0), "error", "max_depth")

## the case max_depth exists for: a search that otherwise does not finish
chk("a 74,524-solution chart answers a bounded question fast", {
  praet <- cora_context(bergschlosser, "PRAET",
             input_labels = c("AGRPOP","PARCL","APROG","PS","RQ","LRC"),
             case_col = "Case", inc_score1 = 0.6, algorithm = "ON-OFF")
  t0 <- Sys.time()
  n <- length(cora_irredundant_sums(praet, max_depth = 7))
  el <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  stopifnot(n == 21L)
  sprintf("21 solutions in %.2fs", el)
})

## ---------------------------------------------------------------------------
hdr("literals are written in a fixed order")

chk("column order does not change the printed terms", {
  d <- data.frame(A = c(1,0,1,0,1,0), B = c(1,1,0,0,1,0),
                  C = c(0,1,1,0,1,1), D = c(1,1,0,1,0,0), O = c(1,1,0,0,1,1))
  terms <- function(x) sort(vapply(cora_prime_implicants(cora_context(x, "O")),
                                   function(i) i$implicant, ""))
  stopifnot(identical(terms(d), terms(d[, c("C","A","D","B","O")])),
            identical(terms(d), terms(d[, c("D","C","B","A","O")])))
  terms(d)
})
chk("non-ASCII condition names work", {
  cjk <- stats::setNames(data.frame(c(1,0,1,0), c(1,1,0,0), c(1,1,0,1)),
                         c("條件乙", "條件甲", "O"))
  vapply(cora_prime_implicants(cora_context(cjk, "O")), function(i) i$implicant, "")
})

## ---------------------------------------------------------------------------
hdr("inputs that must be refused")

bad <- function(label, expr, pattern) chk(label, expr, "error", pattern)

bad("condition not coded from zero",
    cora_prime_implicants(cora_context(
      data.frame(A = c(1,1,0,0), B = c(2,1,2,2), O = c(1,1,0,1)), "O")),
    "coded from 0 upwards")
bad("a constant condition",
    cora_prime_implicants(cora_context(
      data.frame(A = c(1,1,1,1), B = c(1,0,1,0), O = c(1,1,0,1)), "O")),
    "constants")
bad("a fractional value",
    cora_prime_implicants(cora_context(
      data.frame(A = c(1,0.5,1,0), B = c(1,0,0,1), O = c(1,1,0,1)), "O")),
    "integers")
bad("a missing value",
    cora_prime_implicants(cora_context(
      data.frame(A = c(1,NA,1,0), B = c(1,0,0,1), O = c(1,1,0,1)), "O")),
    "integers")
bad("data with no rows",
    cora_prime_implicants(cora_context(
      data.frame(A = integer(0), B = integer(0), O = integer(0)), "O")),
    "no rows")
bad("two columns sharing a name",
    cora_prime_implicants(cora_context(stats::setNames(
      data.frame(c(1,0,1,0), c(0,1,1,0), c(1,0,1,0)), c("A","A","O")), "O")),
    "Duplicated")
bad("the outcome used as its own condition",
    cora_truth_table(cora_context(df, "OUT", input_labels = c("A", "OUT"))),
    "explains only itself")
bad("a case column that names nothing",
    cora_truth_table(cora_context(df, "OUT", case_col = "NOPE")),
    "Case column not found")
bad("n_cut = NA",  cora_context(df, "OUT", n_cut = NA), "n_cut")
bad("inc_score1 = 1.5", cora_context(df, "OUT", inc_score1 = 1.5), "inc_score1")
bad("inc_score2 above inc_score1",
    cora_context(df, "OUT", inc_score1 = 0.4, inc_score2 = 0.9, U = 1), "inc_score2")
bad("inc_score2 without U",
    cora_truth_table(cora_context(df, "OUT", inc_score1 = 0.9, inc_score2 = 0.4)), "U")
bad("outcomes declared inconsistently",
    cora_truth_table(cora_context(
      data.frame(A = c(0,0,1,1), B = c(0,1,0,1),
                 Y1 = c(1,0,1,0), Y3 = c(0,1,2,0)), c("Y1", "Y3{1,2}"))),
    "declared inconsistently")
bad("len_of_tuple = 1.5", cora_data_mining(df, "OUT", len_of_tuple = 1.5), "len_of_tuple")
bad("a diagram value too large for an integer",
    cora_logigram("A{999999999999}<=>F"), "too large")
bad("a term giving one condition two values",
    cora_logigram("A{0}*A{1}<=>F"), "two values")
bad("a tautology has no diagram",
    cora_logigram(cora_irredundant_sums(cora_context(
      data.frame(A = c(1,0,1,0), B = c(1,0,0,1), O = c(1,1,1,1)), "O"))[[1]]),
    "constant function")

chk("cora_recode fixes the coding the error names", {
  g <- data.frame(A = c(1,1,0,0), B = c(2,1,2,2), O = c(1,1,0,1))
  r <- cora_recode(g, "B")
  stopifnot(setequal(unique(r$B), c(0, 1)))       # {2,1} becomes {1,0}
  length(cora_prime_implicants(cora_context(r, "O")))
})

## ---------------------------------------------------------------------------
hdr("warnings and guards")

chk("a many-levelled condition warns under ON-DC", {
  w <- data.frame(A = 0:14, B = rep(0:1, length.out = 15L))
  w$O <- as.integer(w$A > 12L)
  cora_prime_implicants(cora_context(w, "O"))
}, "warning", "ON-OFF")

chk("ON-OFF does not warn about the same data", {
  w <- data.frame(A = 0:14, B = rep(0:1, length.out = 15L))
  w$O <- as.integer(w$A > 12L)
  length(cora_prime_implicants(cora_context(w, "O", algorithm = "ON-OFF")))
})

chk("the summary tables say what they leave out",
    cora_solutions(fresh(), max_solutions = 1), "message", "solutions")
chk("max_solutions = Inf asks for everything",
    { stopifnot(nrow(cora_solutions(fresh(), max_solutions = Inf)) == 2L); TRUE })

## ---------------------------------------------------------------------------
hdr("data mining")

chk("mccluskey pairs", {
  r <- cora_data_mining(mccluskey, c("F1", "F2"), len_of_tuple = 2)
  stopifnot(nrow(r) == 6L, max(r$Score) > 0.6); r$Score
})
chk("a tautology scores zero, not one", {
  z <- data.frame(A = c(1,0,1,0), B = c(1,0,0,1), C = c(0,1,1,0), O = c(1,1,1,1))
  r <- cora_data_mining(z, "O", len_of_tuple = 1)
  stopifnot(all(r$Score == 0)); r$Score
})
chk("automatic widens the search", {
  z <- data.frame(A = c(1,0,0,1), B = c(1,1,0,0), C = c(0,1,1,0), Z = c(0,0,0,1))
  none <- cora_data_mining(z, "Z", len_of_tuple = 1)
  some <- cora_data_mining(z, "Z", len_of_tuple = 1, automatic = TRUE)
  stopifnot(all(none$Score == 0), any(some$Score > 0)); max(some$Score)
})

## ---------------------------------------------------------------------------
hdr("diagrams")

png_dir <- file.path(tempdir(), "cora-acceptance")
dir.create(png_dir, showWarnings = FALSE)
grDevices::pdf(file.path(png_dir, "diagrams.pdf"))

chk("a solution annotates its own diagram", cora_logigram(cora_irredundant_sums(tort)[[1]]))
chk("show_terms labels each gate",
    cora_logigram(cora_irredundant_sums(tort)[[1]], show_terms = TRUE))
chk("title = NA and subtitle = NA suppress the header",
    cora_logigram(cora_irredundant_sums(tort)[[1]], title = NA, subtitle = NA))
chk("a custom header", cora_logigram(cora_irredundant_sums(tort)[[1]],
    title = "Figure 1", subtitle = "N = 18"))
chk("a multi-outcome system draws",
    cora_logigram(cora_irredundant_systems(mn)[[1]], show_terms = TRUE))
chk("a bare expression draws", cora_logigram("A{1}*B{2}+C{0}<=>F"))
chk("case notation draws", cora_logigram("A*B+c*A+b<=>F"))
chk("prime notation draws", cora_logigram("a'*b+c<=>F", notation = "prime"))
chk("square brackets are read", cora_logigram("A[1]*B[2]+C[0]<=>F"))
chk("several outcomes draw",
    cora_logigram(c("A{1}*B{2}+A{2}<=>F1", "A{1}+C{1}*B{2}<=>F2")))
grDevices::dev.off()
cat("     diagrams written to:", file.path(png_dir, "diagrams.pdf"), "\n")

## ---------------------------------------------------------------------------
hdr("optional: the Python cross-check")

if (cora_python_available()) {
  chk("cora_compare_python agrees", {
    r <- cora_compare_python(cora_context(df, "OUT"))
    stopifnot(isTRUE(r$agrees)); "agrees"
  })
} else {
  cat("skip Python not available (this is normal; the package needs none)\n")
}

## ---------------------------------------------------------------------------
hdr("the package's own test suite")

## The test suite ships in the source tarball, not in an ordinary install, so
## it can only be run from here if the package was installed with
## --install-tests. R CMD check runs it either way.
have_tests <- nzchar(system.file("tests", package = "CORA"))
if (!requireNamespace("testthat", quietly = TRUE)) {
  cat("skip testthat is not installed\n")
} else if (!have_tests) {
  cat("skip the tests are not in this install.\n")
  cat("     Install with tests:  R CMD INSTALL --install-tests CORA_0.1.1.tar.gz\n")
  cat("     Or run them through: R CMD check CORA_0.1.1.tar.gz\n")
} else {
  cat("running testthat::test_package(\"CORA\") ...\n")
  tt <- try(testthat::test_package("CORA", reporter = "silent"), silent = TRUE)
  if (inherits(tt, "try-error")) {
    cat(sprintf("%-4s %-56s %s\n", "FAIL", "package test suite",
                conditionMessage(attr(tt, "condition"))))
    FAIL <- FAIL + 1L; FAILED <- c(FAILED, "testthat suite")
  } else {
    d <- as.data.frame(tt)
    nfail <- sum(d$failed) + sum(d$error)
    cat(sprintf("%-4s %-56s %d passed, %d failed\n",
                if (nfail == 0L) "ok" else "FAIL",
                "package test suite", sum(d$passed), nfail))
    if (nfail == 0L) PASS <- PASS + 1L else {
      FAIL <- FAIL + 1L; FAILED <- c(FAILED, "testthat suite") }
  }
}

## ---------------------------------------------------------------------------
cat("\n", strrep("=", 66), "\n", sep = "")
cat(sprintf("%d checks passed, %d failed\n", PASS, FAIL))
if (FAIL > 0L) {
  cat("\nfailed:\n"); cat(paste0("  - ", FAILED, collapse = "\n"), "\n")
  cat("\nPlease send this whole transcript along with sessionInfo().\n")
} else {
  cat("\nEverything behaved as expected.\n")
}
cat("\n"); print(utils::sessionInfo())
if (FAIL > 0L && !interactive()) quit(status = 1L)
