## ---------------------------------------------------------------------------
## Build and check CORA the way CRAN will.
##
## Run from the package source directory (the one holding DESCRIPTION):
##
##   Rscript tools/check.R
##
## It builds the tarball, runs R CMD check --as-cran over it, prints every
## line that is not "OK", and tells you which of those you can ignore.
##
## Windows: install Rtools first (https://cran.r-project.org/bin/windows/Rtools/)
## so that R CMD build and check are available.
## ---------------------------------------------------------------------------

pkg <- "."
if (!file.exists(file.path(pkg, "DESCRIPTION")))
  stop("Run this from the package source directory (the one with DESCRIPTION).")

desc <- read.dcf(file.path(pkg, "DESCRIPTION"))
name <- desc[1, "Package"]; ver <- desc[1, "Version"]
tarball <- sprintf("%s_%s.tar.gz", name, ver)

cat("R           :", R.version.string, "\n")
cat("package     :", name, ver, "\n")
cat("pandoc      :", if (requireNamespace("rmarkdown", quietly = TRUE) &&
                         rmarkdown::pandoc_available())
                       as.character(rmarkdown::pandoc_version()) else
                       "NOT FOUND (the vignette will not build)", "\n")
has <- function(x) nzchar(Sys.which(x))
cat("qpdf        :", if (has("qpdf")) "found" else
    "NOT FOUND (check will warn; harmless, CRAN has it)", "\n")
cat("LaTeX       :", if (has("pdflatex")) "found" else
    "NOT FOUND (use --no-manual, as below)", "\n\n")

## --- 1. regenerate the documentation, if roxygen2 is available -------------
if (requireNamespace("roxygen2", quietly = TRUE)) {
  cat("-- roxygen2::roxygenise()\n")
  roxygen2::roxygenise(pkg)
} else {
  cat("-- skipping roxygenise (roxygen2 not installed)\n")
}

## --- 2. build --------------------------------------------------------------
cat("\n-- R CMD build\n")
unlink(tarball)
bout <- system2(file.path(R.home("bin"), "R"), c("CMD", "build", shQuote(pkg)),
                stdout = TRUE, stderr = TRUE)
cat(paste(bout, collapse = "\n"), "\n")
if (!file.exists(tarball)) stop("build failed: ", tarball, " was not produced")

## --- 3. check --------------------------------------------------------------
args <- c("CMD", "check", "--as-cran", shQuote(tarball))
if (!has("pdflatex")) args <- append(args, "--no-manual", after = 2L)
cat("\n-- R CMD", paste(args[-1], collapse = " "), "\n")
t0 <- Sys.time()
cout <- system2(file.path(R.home("bin"), "R"), args,
                stdout = TRUE, stderr = TRUE)
elapsed <- as.numeric(difftime(Sys.time(), t0, units = "mins"))
logfile <- file.path(paste0(name, ".Rcheck"), "00check.log")
cat(sprintf("   finished in %.1f minutes\n", elapsed))

lines <- if (file.exists(logfile)) readLines(logfile) else cout

## --- 4. report -------------------------------------------------------------
cat("\n", strrep("=", 70), "\n", sep = "")
flagged <- grep("^\\* checking", lines, value = TRUE)
## "extension type ... Package" just reports what was checked, and the
## "using ..." lines report the toolchain; neither is a finding.
flagged <- flagged[!grepl("OK$|extension type|^\\* checking for file|using ", flagged)]
if (length(flagged) == 0L) {
  cat("Every check returned OK.\n")
} else {
  cat("Checks that did not return OK:\n\n")
  for (f in flagged) {
    i <- which(lines == f)[1]
    cat(sub("^\\* checking", " ", f), "\n")
    j <- i + 1L
    while (j <= length(lines) && !grepl("^\\* ", lines[[j]]) && nzchar(lines[[j]])) {
      cat("     ", lines[[j]], "\n"); j <- j + 1L
    }
    cat("\n")
  }
}
cat(grep("^Status", lines, value = TRUE), "\n")

## Which of those are the machine rather than the package.
env <- c(
  "locale"   = "Sys.setlocale|cannot be honored",
  "qpdf"     = "qpdf' is needed",
  "network"  = "unable to access index|unable to verify current time|Status: 403|Status: Error",
  "LaTeX"    = "pdflatex is not available|Rd2pdf")
hits <- names(env)[vapply(env, function(p) any(grepl(p, lines)), logical(1))]
if (length(hits)) {
  cat("\nOf those, these come from this machine and not from the package:\n")
  for (h in hits) cat("  -", switch(h,
    locale  = "the session locale could not be set (R CMD check tries en_US.UTF-8)",
    qpdf    = "qpdf is not installed, so PDF size cannot be checked",
    network = "no network, so the CRAN incoming checks and URL checks could not run",
    LaTeX   = "no LaTeX, so the PDF manual was not built"), "\n")
  cat("\nCRAN's own machines have all of these, so they will not appear there.\n")
  cat("What matters is whether anything ELSE is listed above.\n")
}
cat("\nFull log:", normalizePath(logfile, mustWork = FALSE), "\n")
cat("Test output:", file.path(paste0(name, ".Rcheck"), "tests", "testthat.Rout"), "\n")
