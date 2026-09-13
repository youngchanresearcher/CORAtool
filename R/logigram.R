## LOGIGRAM: two-level logic diagrams for Boolean and multi-value functions
## in disjunctive normal form.

LOGIGRAM_SPLIT <- "^([^<(=|>)-]+)(<*(=|-)>*(.+))$"

logigram_clean <- function(input) {
  x <- gsub("[[:space:]]", "", as.character(input))
  ## Square brackets are the multi-value notation of the QCA package, curly
  ## brackets that of CORA and QCApro. Both are read; both mean the same.
  x <- chartr("[]", "{}", x)
  x[nzchar(x)]
}

## Literal patterns: a binary term is a product of plain names, a multi-value
## term a product of names carrying a single value in curly brackets.
BINARY_TERM <- "[^+*{}=<>-]+"
MV_TERM <- "[^+*{}=<>-]+\\{[0-9]+\\}"

logigram_matches <- function(x, term) {
  body <- sprintf("%s(([+*])%s)*", term, term)
  patterns <- c(sprintf("^%s(<*=>[^+*=<>-]+)$", body),
                sprintf("^%s(=[^+*=<>-]+)$", body),
                sprintf("^%s(<*->[^+*=<>-]+)$", body))
  all(vapply(x, function(s) any(vapply(patterns, function(p) grepl(p, s),
                                       logical(1))), logical(1)))
}

logigram_mode <- function(input) {
  x <- logigram_clean(input)
  if (length(x) == 0L) return("INVALID")
  if (logigram_matches(x, BINARY_TERM)) {
    return(if (length(x) > 1L) "MULTI_OUTPUT" else "BOOLEAN")
  }
  if (logigram_matches(x, MV_TERM)) {
    return(if (length(x) > 1L) "MV_MULTI_OUTPUT" else "MULTI_VALUE")
  }
  "INVALID"
}

logigram_lhs <- function(x) sub(LOGIGRAM_SPLIT, "\\1", x)
logigram_rhs <- function(x) sub(LOGIGRAM_SPLIT, "\\4", x)

## Converts prime notation (a' for a negated literal) to case notation.
prime_to_case <- function(input) {
  vapply(logigram_clean(input), function(elm) {
    sep <- if (grepl("=", elm, fixed = TRUE)) "=" else
      if (grepl("-", elm, fixed = TRUE)) "-" else
        stopf("Invalid input entered!")
    parts <- strsplit(elm, sep, fixed = TRUE)[[1L]]
    onset <- parts[[1L]]
    offset <- paste(parts[-1L], collapse = sep)
    if (grepl("[A-Z]", onset)) stopf("Invalid input entered!")
    terms <- strsplit(onset, "+", fixed = TRUE)[[1L]]
    new_terms <- vapply(terms, function(term) {
      lits <- strsplit(term, "*", fixed = TRUE)[[1L]]
      paste(vapply(lits, function(lit) {
        if (grepl("'", lit, fixed = TRUE)) tolower(gsub("'", "", lit, fixed = TRUE))
        else toupper(lit)
      }, character(1)), collapse = "*")
    }, character(1))
    paste0(paste(new_terms, collapse = "+"), "=", offset)
  }, character(1), USE.NAMES = FALSE)
}

## Parses one or more DNF functions into variables, implicants and outputs.
logigram_parse <- function(input, notation = c("case", "prime")) {
  notation <- match.arg(notation)
  if (notation == "prime") input <- prime_to_case(input)
  x <- logigram_clean(input)
  mode <- logigram_mode(x)
  if (mode == "INVALID") stopf("Unsupported input entered.")
  multi_value <- mode %in% c("MULTI_VALUE", "MV_MULTI_OUTPUT")
  multi_output <- mode %in% c("MULTI_OUTPUT", "MV_MULTI_OUTPUT")

  outputs <- logigram_rhs(x)
  terms_per_f <- lapply(logigram_lhs(x), function(l) {
    strsplit(l, "+", fixed = TRUE)[[1L]]
  })

  ## A term of "1" or "0" makes its function constant. There is nothing to
  ## draw, and treating the digit as a condition would produce a diagram with
  ## an input bus named "1".
  constant <- vapply(terms_per_f, function(terms) any(terms %in% c("0", "1")),
                     logical(1))
  if (any(constant)) {
    k <- which(constant)[[1L]]
    term <- terms_per_f[[k]][terms_per_f[[k]] %in% c("0", "1")][[1L]]
    stopf(paste0("A constant function has no two-level diagram: the ",
                 "expression for %s contains the term \"%s\"."),
          outputs[[k]], term)
  }

  all_terms <- unlist(terms_per_f, use.names = FALSE)
  literals <- unlist(lapply(all_terms, function(t) {
    strsplit(t, "*", fixed = TRUE)[[1L]]
  }), use.names = FALSE)
  variables <- if (multi_value) {
    sort(unique(sub("\\{.*$", "", literals)))
  } else {
    sort(unique(toupper(literals)))
  }
  if (notation == "prime" && !multi_value) variables <- tolower(variables)

  ## One entry per distinct implicant, recording the functions it feeds.
  keys <- character(0)
  implicants <- list()
  for (fi in seq_along(terms_per_f)) {
    for (term in terms_per_f[[fi]]) {
      lits <- strsplit(term, "*", fixed = TRUE)[[1L]]
      values <- rep(NA_integer_, length(variables))
      if (multi_value) {
        parsed <- regmatches(lits, regexec("^(.+)\\{([0-9]+)\\}$", lits))
        for (p in parsed) {
          if (length(p) == 3L) {
            values[match(p[[2L]], variables)] <- as.integer(p[[3L]])
          }
        }
      } else {
        for (i in seq_along(variables)) {
          if (toupper(variables[[i]]) %in% toupper(lits)) {
            values[[i]] <- as.integer(
              any(lits == toupper(variables[[i]]))
            )
          }
        }
      }
      key <- paste(values, collapse = ",")
      pos <- match(key, keys)
      if (is.na(pos)) {
        keys <- c(keys, key)
        implicants[[length(implicants) + 1L]] <-
          list(values = values, outputs = fi, label = term)
      } else {
        implicants[[pos]]$outputs <- sort(unique(c(implicants[[pos]]$outputs, fi)))
      }
    }
  }

  ## Single-literal implicants are drawn first; they bypass the AND gates.
  n_lit <- vapply(implicants, function(i) sum(!is.na(i$values)), integer(1))
  implicants <- implicants[order(n_lit != 1L)]

  list(variables = variables, implicants = implicants, outputs = outputs,
       multi_value = multi_value, multi_output = multi_output)
}

## ------------------------------------------------------------------ drawing

draw_and_gate <- function(x0, y, w, h, col) {
  r <- h / 2
  body_x <- x0 + w - r
  theta <- seq(-pi / 2, pi / 2, length.out = 40)
  xs <- c(x0, body_x, body_x + r * cos(theta), body_x, x0)
  ys <- c(y - r, y - r, y + r * sin(theta), y + r, y + r)
  graphics::polygon(xs, ys, col = col, border = "black")
}

draw_or_gate <- function(x0, y, w, h, col) {
  r <- h / 2
  t <- seq(-1, 1, length.out = 80)
  ## Concave back edge, and two arcs sweeping forward to a rounded nose.
  back_x <- x0 + 0.22 * w * (1 - t^2)
  nose_x <- x0 + w - 0.55 * w * t^2
  graphics::polygon(c(back_x, rev(nose_x)), c(y + r * t, rev(y + r * t)),
                    col = col, border = "black")
}

draw_bubble <- function(x, y, r) {
  theta <- seq(0, 2 * pi, length.out = 40)
  graphics::polygon(x + r * cos(theta), y + r * sin(theta),
                    col = "white", border = "black")
}

#' Draw a two-level logic diagram
#'
#' Renders a Boolean or multi-value function in disjunctive normal form as a
#' two-level logic diagram: conjunctions become AND gates, the disjunction
#' over them an OR gate. This is an R implementation of LOGIGRAM.
#'
#' @param x A character vector of functions in disjunctive normal form, such
#'   as `"A*B+c*A+b<=>F"` or `"A{1}*B{2}+C{0}<=>F"`, one entry per outcome.
#'   Square brackets are read as curly ones, so the `"A[1]*B[2]"` notation of
#'   the QCA package is accepted too.
#'   A [cora_context()] or a solution from [cora_irredundant_sums()] or
#'   [cora_irredundant_systems()] is accepted directly and converted first.
#' @param color_or Fill colour of the OR gates.
#' @param color_and Fill colour of the AND gates.
#' @param notation `"case"` when a negated literal is written in lower case,
#'   `"prime"` when it is written with a trailing apostrophe.
#' @param ... Passed to methods.
#'
#' @return The parsed diagram, invisibly. Called for the plot it draws.
#'
#' @examples
#' cora_logigram("A*B+c*A+b<=>F")
#' cora_logigram("A{1}*B{2}+C{0}<=>F")
#'
#' df <- data.frame(A = c(1, 0, 1, 0), B = c(1, 0, 0, 1),
#'                  C = c(0, 1, 1, 0), OUT = c(1, 1, 0, 1))
#' cora_logigram(cora_irredundant_sums(cora_context(df, "OUT"))[[1]])
#' @export
cora_logigram <- function(x, ...) UseMethod("cora_logigram")

#' @rdname cora_logigram
#' @export
cora_logigram.default <- function(x, color_or = "lightblue",
                                  color_and = "lemonchiffon",
                                  notation = c("case", "prime"), ...) {
  parsed <- logigram_parse(x, notation = notation)
  draw_logigram(parsed, color_or = color_or, color_and = color_and)
  invisible(parsed)
}

#' @rdname cora_logigram
#' @export
cora_logigram.cora_system <- function(x, ...) {
  cora_logigram(cora_dnf(x), ...)
}

#' @rdname cora_logigram
#' @export
cora_logigram.cora_system_multi <- function(x, ...) {
  cora_logigram(cora_dnf(x), ...)
}

#' @rdname cora_logigram
#' @export
cora_logigram.cora_context <- function(x, ...) {
  solutions <- if (x$multi_output) cora_irredundant_systems(x)
               else cora_irredundant_sums(x)
  if (length(solutions) == 0L) stopf("No irredundant solution was found.")
  cora_logigram(solutions[[1L]], ...)
}

#' Disjunctive normal form of a solution
#'
#' Renders a solution in the `"A*B+c<=>F"` notation that [cora_logigram()]
#' draws.
#'
#' @param x A solution from [cora_irredundant_sums()] or
#'   [cora_irredundant_systems()].
#' @param ... Unused.
#'
#' @return A character vector with one entry per outcome.
#'
#' @examples
#' df <- data.frame(A = c(1, 0, 1, 0), B = c(1, 0, 0, 1),
#'                  C = c(0, 1, 1, 0), OUT = c(1, 1, 0, 1))
#' cora_dnf(cora_irredundant_sums(cora_context(df, "OUT"))[[1]])
#' @export
cora_dnf <- function(x, ...) UseMethod("cora_dnf")

clean_label <- function(x) gsub("[[:space:]]", "", x)

#' @export
cora_dnf.cora_system <- function(x, ...) {
  terms <- sub("^#", "", vapply(x$system, function(i) i$implicant, character(1)))
  sprintf("%s<=>%s", paste(terms, collapse = "+"), clean_label(x$output))
}

#' @export
cora_dnf.cora_system_multi <- function(x, ...) {
  keep <- vapply(x$system_multiple, function(s) length(s) > 0L, logical(1))
  vapply(which(keep), function(j) {
    terms <- sub("^#", "",
                 vapply(x$system_multiple[[j]], function(i) i$implicant,
                        character(1)))
    sprintf("%s<=>%s", paste(terms, collapse = "+"),
            clean_label(x$output_labels[[j]]))
  }, character(1))
}

draw_logigram <- function(parsed, color_or = "lightblue",
                          color_and = "lemonchiffon") {
  variables <- parsed$variables
  implicants <- parsed$implicants
  outputs <- parsed$outputs
  nv <- length(variables)
  ni <- length(implicants)
  no <- length(outputs)
  if (ni == 0L) stopf("Nothing to draw: the expression has no implicants.")

  lit_gap <- 0.42
  bubble_r <- 0.1

  ## Each implicant gets a band tall enough for one line per literal.
  n_lit <- vapply(implicants, function(i) sum(!is.na(i$values)), integer(1))
  band_h <- pmax(0.9, (n_lit + 0.6) * lit_gap)
  ## Laid out from the bottom up so that the first implicant ends up on top.
  band_top <- rev(cumsum(rev(band_h) + 0.45))
  row_y <- band_top - band_h / 2

  bus_gap <- 0.75
  bus_x <- seq_len(nv) * bus_gap
  gate_x <- max(bus_x) + 1.5
  gate_w <- 1.6
  collector_x <- gate_x + gate_w + 0.7
  ## Each implicant jogs upward on its own vertical, so the routes stay apart.
  jog_x <- collector_x + (seq_len(ni) - 1L) * 0.18
  or_x <- max(jog_x) + 0.8
  or_w <- 1.5

  ## Literal rows inside a band, top to bottom.
  lit_y <- function(i) {
    k <- n_lit[[i]]
    if (k <= 1L) return(row_y[[i]])
    row_y[[i]] + rev(seq_len(k) - (k + 1) / 2) * lit_gap
  }

  or_h <- vapply(seq_len(no), function(k) {
    rows <- which(vapply(implicants, function(i) k %in% i$outputs, logical(1)))
    max(1, length(rows) + 0.6) * lit_gap
  }, numeric(1))
  or_y <- vapply(seq_len(no), function(k) {
    rows <- which(vapply(implicants, function(i) k %in% i$outputs, logical(1)))
    if (length(rows) == 0L) mean(row_y) else mean(row_y[rows])
  }, numeric(1))
  ## Stack the OR gates in the order the outputs were given, first on top,
  ## so the diagram reads like the solution it was built from.
  if (no > 1L) {
    stacked <- numeric(no)
    stacked[[1L]] <- or_y[[1L]]
    for (k in seq_len(no)[-1L]) {
      min_gap <- (or_h[[k - 1L]] + or_h[[k]]) / 2 + 0.4
      stacked[[k]] <- min(or_y[[k]], stacked[[k - 1L]] - min_gap)
    }
    or_y <- stacked + (mean(or_y) - mean(stacked))
  }

  ## An OR gate sitting at the height of an implicant row would put its input
  ## line on top of that row's output line, which reads as a connection that
  ## is not there. Shift the whole stack by the smallest offset that avoids it.
  collides <- function(shift) {
    any(vapply(or_y + shift,
               function(y) any(abs(row_y - y) < 0.2), logical(1)))
  }
  for (shift in c(0, 0.5, -0.5, 1, -1) * lit_gap) {
    if (!collides(shift)) {
      or_y <- or_y + shift
      break
    }
  }

  top <- max(c(band_top, or_y + or_h / 2)) + 0.9
  bottom <- min(c(band_top - band_h, or_y - or_h / 2)) - 0.5

  ## Left boundary of an OR gate at a given height (its back edge is concave).
  or_back_x <- function(k, yy) {
    t <- (yy - or_y[[k]]) / (or_h[[k]] / 2)
    t <- max(-1, min(1, t))
    or_x + 0.22 * or_w * (1 - t^2)
  }

  op <- graphics::par(mar = c(0.4, 0.4, 0.4, 0.4))
  on.exit(graphics::par(op), add = TRUE)
  graphics::plot.new()
  graphics::plot.window(xlim = c(bus_x[[1L]] - 0.5, or_x + or_w + 2.4),
                        ylim = c(bottom, top), asp = 1)

  for (j in seq_len(nv)) {
    graphics::segments(bus_x[[j]], bottom + 0.15, bus_x[[j]], top - 0.5,
                       col = "grey45")
    graphics::text(bus_x[[j]], top - 0.28, variables[[j]], font = 2, cex = 0.9)
  }

  ## Which OR gate input each implicant feeds, per output.
  stub_y <- vector("list", no)
  for (k in seq_len(no)) {
    rows <- which(vapply(implicants, function(i) k %in% i$outputs, logical(1)))
    m <- length(rows)
    ys <- if (m <= 1L) or_y[[k]] else
      or_y[[k]] + rev(seq_len(m) - (m + 1) / 2) * lit_gap
    stub_y[[k]] <- stats::setNames(ys, as.character(rows))
  }

  for (i in seq_len(ni)) {
    impl <- implicants[[i]]
    lit_idx <- which(!is.na(impl$values))
    ys <- lit_y(i)
    single <- n_lit[[i]] == 1L

    for (m in seq_along(lit_idx)) {
      j <- lit_idx[[m]]
      yy <- ys[[m]]
      negated <- !parsed$multi_value && impl$values[[j]] == 0L
      x_end <- if (single) jog_x[[i]] else gate_x
      trim <- if (negated && !single) 2 * bubble_r else 0
      graphics::segments(bus_x[[j]], yy, x_end - trim, yy)
      graphics::points(bus_x[[j]], yy, pch = 16, cex = 0.55)
      if (negated && !single) draw_bubble(x_end - bubble_r, yy, bubble_r)
      if (parsed$multi_value) {
        graphics::text(bus_x[[j]] + 0.12, yy + 0.2,
                       sprintf("{%d}", impl$values[[j]]), cex = 0.7,
                       adj = c(0, 0.5))
      }
    }

    if (!single) {
      h <- max(0.7, (n_lit[[i]] + 0.4) * lit_gap)
      draw_and_gate(gate_x, row_y[[i]], gate_w, h, color_and)
      graphics::segments(gate_x + gate_w, row_y[[i]], jog_x[[i]], row_y[[i]])
    }

    ## Route the implicant into every OR gate it feeds.
    src_y <- if (single) ys[[1L]] else row_y[[i]]
    negated_single <- single &&
      !parsed$multi_value && impl$values[[lit_idx[[1L]]]] == 0L
    for (k in impl$outputs) {
      target <- stub_y[[k]][[as.character(i)]]
      graphics::segments(jog_x[[i]], src_y, jog_x[[i]], target)
      x_gate <- or_back_x(k, target)
      trim <- if (negated_single) 2 * bubble_r else 0
      graphics::segments(jog_x[[i]], target, x_gate - trim, target)
      if (negated_single) draw_bubble(x_gate - bubble_r, target, bubble_r)
    }
  }

  for (k in seq_len(no)) {
    draw_or_gate(or_x, or_y[[k]], or_w, or_h[[k]], color_or)
    graphics::segments(or_x + or_w, or_y[[k]], or_x + or_w + 0.7, or_y[[k]])
    graphics::text(or_x + or_w + 0.85, or_y[[k]], outputs[[k]], font = 2,
                   adj = c(0, 0.5), cex = 0.95)
  }
  invisible(NULL)
}
