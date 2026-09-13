## Generate the same summary from the R implementation, for cross-checking.
args <- commandArgs(trailingOnly = TRUE)
for (f in list.files("R", full.names = TRUE)) source(f)

norm <- function(x) if (length(x) == 0L || is.na(x)) "NA" else sprintf("%.6f", x)

load_spec <- function(spec) {
  if (!is.null(spec$csv)) {
    sep <- if (is.null(spec$sep)) "," else spec$sep
    return(utils::read.csv(spec$csv, sep = sep, stringsAsFactors = FALSE))
  }
  df <- as.data.frame(do.call(rbind, lapply(spec$data, unlist)))
  names(df) <- unlist(spec$columns)
  df
}

run <- function(spec) {
  df <- load_spec(spec)
  kw <- spec$kwargs
  if (is.null(kw)) kw <- list()
  kw <- lapply(kw, function(v) if (is.list(v)) unlist(v) else v)
  if (!is.null(spec$mining)) {
    res <- do.call(cora_data_mining, c(
      list(data = df, output_labels = unlist(spec$outputs),
           len_of_tuple = spec$mining), kw))
    return(list(mining = vapply(seq_len(nrow(res)), function(i) {
      paste(res$Combination[i], res$Nr_of_systems[i], norm(res$Inc_score[i]),
            norm(res$Cov_score[i]), norm(res$Score[i]), sep = "::")
    }, character(1))))
  }
  args <- c(list(data = df, output_labels = unlist(spec$outputs)), kw)
  ctx <- do.call(cora_context, args)
  out <- list()
  tt <- cora_truth_table(ctx)
  out$truth_table <- lapply(seq_len(nrow(tt)), function(i) as.integer(unname(unlist(tt[i, ]))))
  out$truth_table_cols <- names(tt)
  pis <- cora_prime_implicants(ctx)
  multi <- ctx$multi_output
  out$prime_implicants <- sort(vapply(pis, function(p) {
    if (multi) paste0(p$implicant, "|", paste(sort(p$outputs), collapse = ","))
    else p$implicant
  }, character(1)))
  out$pi_coverage <- sort(vapply(pis, function(p) {
    paste0(p$implicant, "::", paste(sort(p$coverage), collapse = ","))
  }, character(1)))
  out$pi_scores <- sort(vapply(pis, function(p) {
    paste0(p$implicant, "::", norm(cora_coverage_score(p)), "::",
           norm(cora_inclusion_score(p)))
  }, character(1)))
  systems <- if (multi) cora_irredundant_systems(ctx) else cora_irredundant_sums(ctx)
  out$solutions <- sort(vapply(systems, function(s) {
    if (multi) {
      paste(vapply(s$system_multiple, function(per_out) {
        paste(sort(vapply(per_out, function(i) i$implicant, character(1))),
              collapse = "+")
      }, character(1)), collapse = "/")
    } else {
      paste(sort(vapply(s$system, function(i) i$implicant, character(1))),
            collapse = "+")
    }
  }, character(1)))
  out$solution_scores <- sort(vapply(systems, function(s) {
    paste0(norm(cora_coverage_score(s)), "::", norm(cora_inclusion_score(s)))
  }, character(1)))
  out
}

specs <- jsonlite::fromJSON(args[[1]], simplifyVector = FALSE)
res <- lapply(specs, run)
cat(jsonlite::toJSON(res, auto_unbox = FALSE, pretty = 1, null = "null"))
