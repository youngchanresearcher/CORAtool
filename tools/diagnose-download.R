## ---------------------------------------------------------------------------
## What is wrong with this .tar.gz?
##
## Point it at the file you downloaded and it will say whether the file is a
## real gzip archive, and if not, what it actually is.
##
##   source("diagnose-download.R")   # then follow the prompt
## or set the path directly:
##   f <- "C:/Users/me/Downloads/CORAtool_0.1.2.tar.gz"; source("diagnose-download.R")
## ---------------------------------------------------------------------------

if (!exists("f") || !is.character(f) || !nzchar(f)) {
  f <- if (interactive()) file.choose() else
    stop("Set f to the path of the file first, e.g.\n",
         '  f <- "C:/temp/CORAtool_0.1.2.tar.gz"')
}

say <- function(...) cat(..., "\n", sep = "")
line <- function() say(strrep("-", 68))

line(); say("file: ", f); line()

if (!file.exists(f)) {
  say("VERDICT: that path does not exist.")
  say("Check the spelling, and remember R wants forward slashes:")
  say('  "C:/Users/you/Downloads/CORAtool_0.1.2.tar.gz"')
} else {
  info <- file.info(f)
  say("size on disk : ", format(info$size, big.mark = ","), " bytes")
  say("last modified: ", format(info$mtime))

  if (grepl(" ", basename(f))) {
    say("")
    say("NOTE: the file name contains a space. The name it was built under is")
    say("      CORAtool_0.1.2.tar.gz, with an underscore. A renamed file usually")
    say("      means the download altered it, so treat the contents as suspect.")
  }

  ## A gzip file always begins 1f 8b 08.
  magic <- readBin(f, "raw", n = 4L)
  say("")
  say("first bytes  : ", paste(as.character(magic), collapse = " "))

  if (length(magic) >= 3L &&
      magic[1] == as.raw(0x1f) && magic[2] == as.raw(0x8b) &&
      magic[3] == as.raw(0x08)) {
    say("             : correct gzip signature")
    listing <- try(untar(f, list = TRUE), silent = TRUE)
    if (inherits(listing, "try-error")) {
      say("")
      say("VERDICT: the header is right but the archive will not open, so the")
      say("         download is incomplete. Download it again.")
      say("")
      say("         ", conditionMessage(attr(listing, "condition")))
    } else {
      say("entries      : ", length(listing), "  (a complete CORAtool has 78)")
      has_desc <- any(grepl("DESCRIPTION$", listing))
      say("DESCRIPTION  : ", if (has_desc) "present" else "MISSING")
      say("")
      if (has_desc && length(listing) > 50L) {
        say("VERDICT: the file is a sound R source package. Install it with")
        say('         install.packages("', f, '",')
        say('                          repos = NULL, type = "source")')
      } else {
        say("VERDICT: the archive opens but stops early -- ", length(listing),
            " of 78 entries,")
        say("         DESCRIPTION ", if (has_desc) "present" else "missing",
            ". The download was cut short.")
        say("         Download it again, and check the finished file is about")
        say("         150,000 bytes.")
      }
    }
  } else {
    head_txt <- suppressWarnings(
      tryCatch(readLines(f, n = 3L, warn = FALSE), error = function(e) character(0)))
    printable <- length(head_txt) &&
      all(grepl("^[[:print:][:space:]]*$", head_txt))
    say("             : NOT a gzip file")
    say("")
    if (printable) {
      say("It is text. The first lines are:")
      for (l in head_txt) say("  | ", substr(l, 1, 70))
      say("")
      if (any(grepl("<!DOCTYPE|<html|<HTML", head_txt))) {
        say("VERDICT: this is an HTML page, not the package. The download")
        say("         returned a web page (a sign-in page or an error page)")
        say("         instead of the file. Download it again.")
      } else {
        say("VERDICT: this is a text file, not a compressed archive.")
      }
    } else if (info$size < 10000) {
      say("VERDICT: far too small (", info$size, " bytes) to be the package,")
      say("         which is about 150,000. The download did not complete, or")
      say("         this is a OneDrive placeholder that was never fetched.")
    } else {
      say("VERDICT: the contents are not a gzip archive. Something between the")
      say("         download and the disk altered the file.")
    }
  }

  if (grepl("OneDrive", f, ignore.case = TRUE)) {
    say("")
    line()
    say("The file is inside OneDrive. OneDrive can leave a placeholder that")
    say("looks like a file but holds no data until it is opened, and it can")
    say("also be mid-sync while R is reading it. Move the file somewhere")
    say("plain before installing:")
    say("")
    say('  dir.create("C:/temp", showWarnings = FALSE)')
    say('  file.copy(f, "C:/temp/CORAtool_0.1.2.tar.gz", overwrite = TRUE)')
    say('  install.packages("C:/temp/CORAtool_0.1.2.tar.gz",')
    say('                   repos = NULL, type = "source")')
  }
}
line()
say("R  : ", R.version.string)
say("tar: ", Sys.getenv("TAR", unset = "(TAR not set; R will use its own)"))
say("Sys.which(\"tar\"): ", Sys.which("tar"))
line()
