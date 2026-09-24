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
old_wd <- setwd(WORKDIR)
on.exit(setwd(old_wd), add = TRUE)

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

if (desc[, "Package"] != "CORAtool") {
  stop("This tarball is package '", desc[, "Package"],
       "', not CORAtool. You have an older build.")
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
                 shQuote(basename(local_tar))),
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
    hit <- regmatches(block[1], regexpr("(NOTE|WARNING|ERROR)\\s*$", block[1]))
    if (length(hit) == 0L) {
      loose <- grep("^\\s*(NOTE|WARNING|ERROR)\\s*$", block[-1], value = TRUE)
      if (length(loose)) hit <- trimws(loose[length(loose)])
    }
    if (length(hit))
      out <- c(out, sprintf("%-64s %s",
                            substr(sub("\\.\\.\\..*$", "", block[1]), 1, 64),
                            trimws(hit)))
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
