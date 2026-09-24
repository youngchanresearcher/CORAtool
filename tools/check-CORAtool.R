## ---------------------------------------------------------------------------
## check-CORAtool.R
##
## Runs R CMD check --as-cran on the CORAtool tarball and prints the part that
## decides whether the package can be submitted: the CRAN incoming feasibility
## block, every check that did not come back OK, and the final status line.
##
## Edit TARBALL below if your copy is somewhere else. Nothing else needs
## changing. Run the whole file at once (source it, or paste it all in).
## ---------------------------------------------------------------------------

TARBALL <- file.path(Sys.getenv("USERPROFILE"), "OneDrive", "Desktop",
                     "CORAtool_0.1.2.tar.gz")
WORKDIR <- "C:/coracheck"

## --- 1. put the tarball somewhere local -------------------------------------
## OneDrive can hold a file as a cloud placeholder, and R CMD check writes a
## large directory next to the tarball, so both go better outside the synced
## folder.

if (!file.exists(TARBALL)) {
  stop("Cannot find:\n  ", TARBALL,
       "\nEdit TARBALL at the top of this script to the real path.")
}
dir.create(WORKDIR, showWarnings = FALSE, recursive = TRUE)
local_tar <- file.path(WORKDIR, basename(TARBALL))
if (!identical(normalizePath(TARBALL, "/", TRUE),
               normalizePath(local_tar, "/", FALSE))) {
  if (!file.copy(TARBALL, local_tar, overwrite = TRUE)) {
    stop("Could not copy the tarball into ", WORKDIR,
         ". If it lives in OneDrive, right-click it and choose ",
         "\"Always keep on this device\", then run this again.")
  }
}
## No on.exit() here: under source() each top-level line is its own
## evaluation, so on.exit() would undo the setwd() before the check ran.
## R CMD check writes CORAtool.Rcheck into the working directory, which is
## why it has to be WORKDIR, and the tarball is passed by its full path.
setwd(WORKDIR)

## --- 2. say what the file actually is ---------------------------------------
## A truncated download and a renamed file both fail here rather than halfway
## through the check, where the message is harder to read.

size <- file.info(local_tar)$size
if (is.na(size)) stop("The file is there but unreadable (a OneDrive placeholder?).")

entries <- tryCatch(untar(local_tar, list = TRUE),
                    error = function(e) stop("Not a readable .tar.gz: ",
                                             conditionMessage(e)))
untar(local_tar, files = "CORAtool/DESCRIPTION", exdir = tempdir())
desc <- read.dcf(file.path(tempdir(), "CORAtool", "DESCRIPTION"))

cat("--- the file -----------------------------------------------------------\n")
cat(sprintf("path      : %s\n", local_tar))
cat(sprintf("size      : %d bytes\n", size))
cat(sprintf("entries   : %d (expected 78)\n", length(entries)))
cat(sprintf("Package   : %s\n", desc[, "Package"]))
cat(sprintf("Version   : %s\n", desc[, "Version"]))
cat("\n")

EXPECTED_VERSION <- "0.1.2"
if (desc[, "Package"] != "CORAtool") {
  stop("This tarball is package '", desc[, "Package"],
       "', not CORAtool. You have an older build.")
}
if (desc[, "Version"] != EXPECTED_VERSION) {
  stop("This tarball is version ", desc[, "Version"], ", not ",
       EXPECTED_VERSION, ". You have an older build.")
}

## --- 3. run the check -------------------------------------------------------
## _R_CHECK_FORCE_SUGGESTS_=false lets the check run without reticulate
## installed; reticulate is only used by the optional Python cross-check.

Sys.setenv("_R_CHECK_FORCE_SUGGESTS_" = "false")
cat("--- running R CMD check --as-cran (a few minutes) ----------------------\n")
cat("The CRAN incoming feasibility step downloads the CRAN package index,\n")
cat("so it sits quiet for a minute. That is normal.\n\n")
flush.console()

t0 <- Sys.time()
out <- system2(file.path(R.home("bin"), "R"),
               c("CMD", "check", "--as-cran", "--no-manual",
                 shQuote(normalizePath(local_tar, "/"))),
               stdout = TRUE, stderr = TRUE)
elapsed <- as.numeric(difftime(Sys.time(), t0, units = "mins"))

full_log <- file.path(WORKDIR, "check-output.txt")
writeLines(out, full_log)
cat(sprintf("finished in %.1f minutes; full output written to\n  %s\n\n",
            elapsed, full_log))

## --- 4. print the part that matters -----------------------------------------
## The incoming feasibility block runs from its own header to the next header.

show_block <- function(lines, header) {
  starts <- grep(header, lines)
  if (length(starts) == 0L) return(invisible(FALSE))
  from <- starts[1]
  rest <- grep("^\\* ", lines)
  to <- rest[rest > from]
  to <- if (length(to)) to[1] - 1L else length(lines)
  writeLines(lines[from:to])
  invisible(TRUE)
}

cat("--- CRAN incoming feasibility ------------------------------------------\n")
if (!show_block(out, "^\\* checking CRAN incoming feasibility")) {
  cat("(no such block -- the check stopped before it got there)\n")
}

## A check can report its verdict on its own header line ("... NOTE") or, when
## it printed something first, on a line of its own further down. Reading each
## check as a block catches both.

verdicts <- function(lines) {
  heads <- grep("^\\* ", lines)
  if (length(heads) == 0L) return(character(0))
  bounds <- c(heads, length(lines) + 1L)
  out <- character(0)
  for (i in seq_along(heads)) {
    block <- lines[bounds[i]:(bounds[i + 1L] - 1L)]
    label <- substr(sub("\\.\\.\\..*$", "", block[1]), 1, 64)
    hit <- regmatches(block[1], regexpr("(NOTE|WARNING|ERROR)\\s*$", block[1]))
    loose_at <- grep("^\\s*(NOTE|WARNING|ERROR)\\s*$", block)
    loose_at <- loose_at[loose_at > 1L]
    if (length(hit) == 0L && length(loose_at)) {
      at <- loose_at[length(loose_at)]
      hit <- trimws(block[at])
      ## A header that already said OK did not produce this verdict: some
      ## check printed it without a header of its own. Name it by the line
      ## that explains it instead of blaming the OK check above.
      if (grepl("\\bOK\\s*$", block[1]) && at < length(block))
        label <- paste0("  (unlabelled) ", substr(block[at + 1L], 1, 50))
    }
    if (length(hit))
      out <- c(out, sprintf("%-64s %s", label, trimws(hit)))
  }
  out
}

cat("\n--- every check that was not OK ----------------------------------------\n")
not_ok <- verdicts(out)
if (length(not_ok)) writeLines(not_ok) else cat("(all checks OK)\n")

cat("\n--- status -------------------------------------------------------------\n")
status <- grep("^Status:", out, value = TRUE)
writeLines(if (length(status)) status else "(no status line -- check did not finish)")

## --- 5. the one question this run was for -----------------------------------

cat("\n--- the name ------------------------------------------------------------\n")
if (any(grepl("Conflicting package names", out))) {
  cat("TAKEN. CRAN already has a package whose name matches 'CORAtool'\n")
  cat("ignoring case. The package needs another name.\n")
  writeLines(grep("Conflicting package names", out, value = TRUE))
} else if (any(grepl("^\\* checking CRAN incoming feasibility", out)) &&
           !any(grepl("need Internet access to use CRAN incoming checks", out))) {
  cat("FREE. The incoming check reached CRAN and did not object to the name.\n")
  if (any(grepl("New submission", out)))
    cat("'New submission' is expected on a first submission and is not a problem.\n")
} else {
  cat("UNKNOWN. The incoming check could not reach CRAN, so it never compared\n")
  cat("the name. Check the machine's internet connection and run this again.\n")
}

## --- 6. the three things CRAN asked for in 0.1.2 ----------------------------
## Read from the copy the check itself installed, so this is the build that
## would be submitted rather than whatever is in your usual library.

cat("\n--- the three CRAN requests ---------------------------------------------\n")
lib <- file.path(WORKDIR, "CORAtool.Rcheck")
if (!dir.exists(file.path(lib, "CORAtool"))) {
  cat("(the check did not install the package, so these cannot be read)\n")
} else {
  d <- packageDescription("CORAtool", lib.loc = lib)
  descr <- gsub("\\s+", " ", d$Description)
  title <- d$Title

  ok1 <- !startsWith(tolower(descr), tolower(title)) &&
         !grepl("^(this package|coratool|a package)", tolower(descr))
  cat(sprintf("%-4s Description does not open with the title or package name\n",
              if (ok1) "ok" else "FAIL"))
  cat(sprintf("     starts: \"%s ...\"\n", substr(descr, 1, 60)))

  expanded <- "insufficient but non-redundant part of an unnecessary but sufficient"
  pos_long <- regexpr(expanded, descr, fixed = TRUE)
  pos_acro <- regexpr("INUS", descr, fixed = TRUE)
  ok2 <- pos_long > 0 && pos_acro > pos_long
  cat(sprintf("%-4s INUS is spelled out before the acronym is used\n",
              if (ok2) "ok" else "FAIL"))

  ns <- loadNamespace("CORAtool", lib.loc = lib)
  offenders <- Filter(function(f) {
    obj <- get(f, envir = ns)
    is.function(obj) && !startsWith(f, "print.") &&
      grepl("\\b(cat|print|writeLines)\\(",
            paste(deparse(body(obj)), collapse = "\n"))
  }, ls(ns, all.names = TRUE))
  ok3 <- length(offenders) == 0L &&
         is.function(getS3method("print", "cora_comparison", envir = ns))
  cat(sprintf("%-4s only print() methods write to the console\n",
              if (ok3) "ok" else "FAIL"))
  if (length(offenders))
    cat("     offenders:", paste(offenders, collapse = ", "), "\n")
}

