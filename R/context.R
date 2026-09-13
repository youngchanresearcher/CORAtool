COLUMN_LABELS <- c(LETTERS, "AA", "BB", "CC", "DD", "EE", "FF")

OUTPUT_PATTERN <- "^([a-zA-Z0-9]+)\\{([0-9]+(,[0-9]+)*)\\}$"
REGULAR_OUTPUT <- "^([a-zA-Z0-9]+)"

#' Create an optimisation context
#'
#' Bundles the data and the analytical choices that drive a Combinational
#' Regularity Analysis. The context is evaluated lazily: the truth table,
#' the prime implicants and the irredundant solutions are each computed on
#' first request and cached afterwards.
#'
#' @param data A data frame. Input columns must hold non-negative integers
#'   coded from zero upwards; output columns must be binary unless their
#'   analysed values are declared in `output_labels`.
#' @param output_labels Character vector naming the outcome columns. A
#'   multi-value outcome declares the values that count as positive in curly
#'   brackets, e.g. `"OUT{1,2}"`.
#' @param input_labels Character vector naming the input columns. Defaults to
#'   every column that is neither an outcome nor the case column.
#' @param case_col Name of the column holding case identifiers, or `NULL`.
#' @param n_cut Minimum number of cases below which a truth table row is
#'   declared a don't care.
#' @param inc_score1 Minimum sufficiency inclusion score for an output
#'   function value of 1.
#' @param inc_score2 Maximum sufficiency inclusion score for an output
#'   function value of 0, or `NULL`.
#' @param U Either 0 or 1; required when `inc_score2` is given.
#' @param rename_columns If `TRUE`, input columns are renamed to single
#'   letters in alphabetical order.
#' @param algorithm `"ON-DC"` (the classical Quine-McCluskey algorithm over
#'   positive and don't care terms) or `"ON-OFF"` (McCluskey's modified
#'   algorithm over positive and negative terms).
#'
#' @return An object of class `cora_context`.
#'
#' @examples
#' df <- data.frame(A = c(1, 0, 1, 0), B = c(1, 0, 0, 1),
#'                  C = c(0, 1, 1, 0), OUT = c(1, 1, 0, 1))
#' ctx <- cora_context(df, output_labels = "OUT")
#' cora_prime_implicants(ctx)
#'
#' @seealso [cora_truth_table()], [cora_prime_implicants()],
#'   [cora_irredundant_sums()], [cora_irredundant_systems()]
#' @export
cora_context <- function(data,
                         output_labels,
                         input_labels = NULL,
                         case_col = NULL,
                         n_cut = 1,
                         inc_score1 = 1,
                         inc_score2 = NULL,
                         U = NULL,
                         rename_columns = FALSE,
                         algorithm = c("ON-DC", "ON-OFF")) {
  if (!is.data.frame(data)) stopf("`data` must be a data frame.")
  if (!is.character(output_labels) || length(output_labels) == 0L) {
    stopf("`output_labels` must be a non-empty character vector.")
  }
  algorithm <- match.arg(algorithm)

  ctx <- new.env(parent = emptyenv())
  ctx$data <- data
  ctx$input_labels <- input_labels
  ctx$case_col <- case_col
  ctx$n_cut <- n_cut
  ctx$inc_score1 <- inc_score1
  ctx$inc_score2 <- inc_score2
  ctx$U <- U
  ctx$rename_columns <- isTRUE(rename_columns)
  ctx$output_labels <- output_labels
  ctx$algorithm <- algorithm

  ctx$multi_output <- length(output_labels) > 1L
  ctx$multivalue_output <- FALSE
  ctx$validated <- FALSE
  ctx$preprocessed <- FALSE
  ctx$prepared_rows <- FALSE
  ctx$prime_implicants <- NULL
  ctx$irredundant_sums <- NULL
  ctx$irredundant_systems <- NULL
  ctx$pi_chart <- NULL
  ctx$details <- NULL
  ctx$sol_details <- NULL
  ctx$solution_dataframe <- NULL
  ctx$rename_dictionary <- NULL
  ctx$input_data <- NULL

  class(ctx) <- "cora_context"
  ctx
}

## ---------------------------------------------------------------- validation

validate_context <- function(ctx) {
  if (ctx$validated) return(invisible(ctx))
  data <- ctx$data

  inputs <- if (is.null(ctx$input_labels)) {
    setdiff(names(data), ctx$case_col)
  } else {
    ctx$input_labels
  }
  missing_cols <- setdiff(inputs, names(data))
  if (length(missing_cols)) {
    stopf("Input column(s) not found in the data: %s.",
          paste(missing_cols, collapse = ", "))
  }
  for (col in inputs) {
    v <- data[[col]]
    if (!is.numeric(v) || any(is.na(v)) || any(v != as.integer(v))) {
      stopf("Invalid data input: column '%s' must contain integers.", col)
    }
  }

  ## Outputs: either all multi-value declarations, or all plain names.
  if (all(grepl(OUTPUT_PATTERN, ctx$output_labels))) {
    ctx$multivalue_output <- TRUE
  } else if (!all(grepl(REGULAR_OUTPUT, ctx$output_labels))) {
    stopf("Unsupported output entered!")
  }

  if (ctx$multivalue_output) {
    names_out <- sub(OUTPUT_PATTERN, "\\1", ctx$output_labels)
    value_sets <- lapply(
      sub(OUTPUT_PATTERN, "\\2", ctx$output_labels),
      function(s) sort(unique(as.integer(strsplit(s, ",", fixed = TRUE)[[1L]])))
    )
    missing_out <- setdiff(names_out, names(data))
    if (length(missing_out)) {
      stopf("Outcome column(s) not found in the data: %s.",
            paste(missing_out, collapse = ", "))
    }
    for (i in seq_along(names_out)) {
      k <- names_out[[i]]
      data[[k]] <- as.integer(data[[k]] %in% value_sets[[i]])
    }
    ctx$data <- data
    ctx$output_labels <- names_out
    ctx$output_labels_final <- vapply(
      seq_along(names_out),
      function(i) sprintf("%s{%s}", names_out[[i]],
                          paste(value_sets[[i]], collapse = ", ")),
      character(1)
    )
  } else {
    missing_out <- setdiff(ctx$output_labels, names(data))
    if (length(missing_out)) {
      stopf("Outcome column(s) not found in the data: %s.",
            paste(missing_out, collapse = ", "))
    }
    vals <- unique(unlist(data[ctx$output_labels], use.names = FALSE))
    if (!all(vals %in% c(0, 1))) {
      stopf(paste0("Unsupported output entered! Please specify the ",
                   "analysed output values, e.g. \"%s{1}\"."),
            ctx$output_labels[[1L]])
    }
    ctx$output_labels_final <- ctx$output_labels
  }

  if (is.null(ctx$input_labels)) {
    ctx$input_labels <- setdiff(names(ctx$data),
                                c(ctx$output_labels, ctx$case_col))
  }
  if (length(ctx$input_labels) == 0L) {
    stopf("No input columns were found.")
  }

  input_data <- ctx$data[ctx$input_labels]
  if (is.null(ctx$input_data)) ctx$input_data <- input_data

  constant <- vapply(input_data, function(v) length(unique(v)) == 1L, logical(1))
  if (any(constant)) {
    stopf("Please respecify your input data - constants are not allowed (%s).",
          paste(names(input_data)[constant], collapse = ", "))
  }

  ## CORA expects conditions coded from zero upwards. When a condition skips
  ## zero, the ON-OFF algorithm builds the free-literal domain as
  ## {0, ..., levels - 1} rather than from the values actually present, and
  ## silently drops the rows whose value falls outside it, so coverage sets
  ## and the scores derived from them come out wrong.
  gaps <- vapply(input_data, function(v) {
    u <- sort(unique(as.integer(v)))
    !identical(u, seq.int(0L, length(u) - 1L))
  }, logical(1))
  if (any(gaps)) {
    warning(sprintf(paste0(
      "Condition(s) %s are not coded from 0 upwards. CORA expects the values ",
      "0, 1, 2, ... With the \"ON-OFF\" algorithm such a coding yields wrong ",
      "coverage sets and scores; recode the condition(s) before analysing."),
      paste(sQuote(names(input_data)[gaps], q = FALSE), collapse = ", ")),
      call. = FALSE)
  }

  ctx$validated <- TRUE
  invisible(ctx)
}

## ------------------------------------------------------------- preprocessing

preprocess_data <- function(ctx) {
  if (ctx$preprocessed) return(invisible(ctx))
  validate_context(ctx)

  data <- ctx$data
  case_col <- ctx$case_col
  if (is.null(case_col) || identical(case_col, "-None-")) {
    data[["case_col"]] <- as.character(seq_len(nrow(data)) - 1L)
    case_col <- "case_col"
    ctx$case_col <- case_col
  }

  in_cols <- names(ctx$input_data)
  out_cols <- ctx$output_labels

  ## Group by the input configuration. Groups are ordered ascending on the
  ## input columns from left to right, matching pandas' sorted groupby.
  key <- do.call(paste, c(unname(data[in_cols]), sep = "\r"))
  ord <- do.call(order, unname(data[in_cols]))
  key_ord <- key[ord]
  first <- !duplicated(key_ord)
  group_id <- cumsum(first)
  n_groups <- sum(first)

  res <- data[ord, , drop = FALSE][first, in_cols, drop = FALSE]
  rownames(res) <- NULL
  res[["n"]] <- as.integer(tabulate(group_id, nbins = n_groups))
  res[["Cases"]] <- vapply(
    split(as.character(data[[case_col]][ord]), group_id),
    function(x) paste(x, collapse = ","), character(1),
    USE.NAMES = FALSE
  )
  for (oc in out_cols) {
    vals <- split(as.numeric(data[[oc]][ord]), group_id)
    res[[paste0("Inc_", oc)]] <- vapply(
      vals, function(x) py_round(sum(x) / length(x), 2), numeric(1),
      USE.NAMES = FALSE
    )
  }

  res <- res[res[["n"]] >= ctx$n_cut, , drop = FALSE]
  rownames(res) <- NULL

  inc_cols <- paste0("Inc_", out_cols)
  if (is.null(ctx$inc_score2)) {
    threshold <- ctx$inc_score1
  } else {
    if (is.null(ctx$U)) {
      stopf("When inc_score2 is specified, U must be specified as well.")
    }
    if (!ctx$U %in% c(0, 1)) stopf("U must be 0 or 1.")
    threshold <- if (ctx$U == 1) ctx$inc_score2 else ctx$inc_score1
  }
  for (i in seq_along(out_cols)) {
    res[[out_cols[[i]]]] <- as.integer(res[[inc_cols[[i]]]] >= threshold)
  }

  if (ctx$rename_columns) {
    l <- length(ctx$input_labels)
    if (l > length(COLUMN_LABELS)) {
      stopf("Too many input columns to rename (maximum %d).",
            length(COLUMN_LABELS))
    }
    new_names <- COLUMN_LABELS[seq_len(l)]
    ctx$rename_dictionary <- stats::setNames(new_names, ctx$input_labels)
    names(res)[match(ctx$input_labels, names(res))] <- new_names
    ctx$input_labels <- new_names
  }

  ctx$preprocessed_data_raw <- res
  ctx$preprocessed_data <- res[c(ctx$input_labels, out_cols)]
  rownames(ctx$preprocessed_data) <- NULL
  ctx$preprocessed <- TRUE
  invisible(ctx)
}

#' Truth table of an optimisation context
#'
#' Aggregates the cases into configurations, applies the frequency cut-off
#' and the inclusion cut-offs, and returns the resulting truth table.
#'
#' @param ctx A [cora_context()].
#' @param raw If `TRUE`, also return the case counts, the case labels and the
#'   raw inclusion scores of every configuration.
#'
#' @return A data frame.
#'
#' @examples
#' df <- data.frame(A = c(1, 0, 1, 1, 1), B = c(0, 1, 1, 1, 1),
#'                  C = c(0, 0, 1, 1, 1), O = c(1, 1, 0, 1, 1))
#' cora_truth_table(cora_context(df, "O", inc_score1 = 0.5))
#' @export
cora_truth_table <- function(ctx, raw = FALSE) {
  stopifnot(inherits(ctx, "cora_context"))
  preprocess_data(ctx)
  if (isTRUE(raw)) ctx$preprocessed_data_raw else ctx$preprocessed_data
}

## Number of distinct values per input column in the truth table. A column
## that has collapsed to a single value is still treated as binary.
context_levels <- function(ctx) {
  inputs <- ctx$preprocessed_data[ctx$input_labels]
  if (length(ctx$input_labels) == 1L) {
    return(length(inputs[[1L]]))
  }
  vapply(inputs, function(v) {
    u <- unique_in_order(v)
    if (length(u) > 1L) length(u) else 2L
  }, integer(1), USE.NAMES = FALSE)
}

## Value domains per input column, in order of first appearance, as used to
## span the full configuration space of the ON-DC algorithm.
context_dims <- function(ctx) {
  inputs <- ctx$preprocessed_data[ctx$input_labels]
  if (length(ctx$input_labels) == 1L) {
    return(list(as.integer(inputs[[1L]])))
  }
  lapply(inputs, function(v) {
    u <- as.integer(unique_in_order(v))
    if (length(u) > 1L) u else c(0L, 1L)
  })
}

## Builds the configuration space used by the ON-DC algorithm: every input
## combination except those whose outcomes are all zero, together with the
## indices of the positive ("care") rows inside it.
prepare_rows <- function(ctx) {
  if (ctx$prepared_rows) return(invisible(ctx))
  preprocess_data(ctx)

  pdata <- ctx$preprocessed_data
  out_cols <- ctx$output_labels
  in_cols <- ctx$input_labels
  n_out <- length(out_cols)

  out_mat <- as.matrix(pdata[out_cols])
  positive <- apply(out_mat == 1L, 1L, any)
  negative <- apply(out_mat == 0L, 1L, all)

  dims <- context_dims(ctx)
  levels <- vapply(dims, length, integer(1), USE.NAMES = FALSE)

  all_inputs <- cartesian_product(dims)
  colnames(all_inputs) <- in_cols
  all_keys <- apply(all_inputs, 1L, int_key)

  in_mat <- as.matrix(pdata[in_cols])
  storage.mode(in_mat) <- "integer"
  row_keys <- apply(in_mat, 1L, int_key)

  drop_idx <- match(row_keys[negative], all_keys)
  keep <- rep(TRUE, nrow(all_inputs))
  keep[drop_idx[!is.na(drop_idx)]] <- FALSE
  table_mat <- all_inputs[keep, , drop = FALSE]
  table_keys <- all_keys[keep]

  ## Zero-based indices, matching the reference implementation.
  cares <- match(row_keys[positive], table_keys) - 1L

  if (ctx$multi_output) {
    ## Outcome columns of the positive rows, in configuration-space order.
    pos_rows <- which(positive)
    ord <- order(match(row_keys[pos_rows], table_keys))
    ctx$outputcolumns <- t(out_mat[pos_rows[ord], , drop = FALSE])
  } else {
    ctx$outputcolumns <- rep(1L, nrow(pdata))
  }

  ctx$levels <- levels
  ctx$cares <- cares
  ctx$table <- table_mat
  ctx$labels <- in_cols
  ## Zero-based row numbers of the positive truth table rows.
  ctx$positive_cares <- which(positive) - 1L
  ctx$prepared_rows <- TRUE
  invisible(ctx)
}
