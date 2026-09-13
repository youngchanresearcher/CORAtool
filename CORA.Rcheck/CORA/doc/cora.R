## ----include = FALSE----------------------------------------------------------
knitr::opts_chunk$set(collapse = TRUE, comment = "#>", fig.width = 7,
                      fig.height = 4.5)
library(CORA)

## -----------------------------------------------------------------------------
df <- data.frame(A   = c(1, 0, 1, 0),
                 B   = c(1, 0, 0, 1),
                 C   = c(0, 1, 1, 0),
                 OUT = c(1, 1, 0, 1))
ctx <- cora_context(df, output_labels = "OUT")

## -----------------------------------------------------------------------------
cora_truth_table(ctx)

## -----------------------------------------------------------------------------
cora_prime_implicants(ctx)

## -----------------------------------------------------------------------------
cora_pi_chart(ctx)

## -----------------------------------------------------------------------------
cora_irredundant_sums(ctx)

## -----------------------------------------------------------------------------
cora_pi_details(ctx)

## -----------------------------------------------------------------------------
cora_system_details(ctx)
cora_describe(cora_irredundant_sums(ctx)[[1]])

## -----------------------------------------------------------------------------
tort <- cora_context(gross_carvin, "TORT", case_col = "Case",
                     algorithm = "ON-OFF")
cora_irredundant_sums(tort)

## -----------------------------------------------------------------------------
minaret <- cora_context(swiss_minaret, c("X", "M"), algorithm = "ON-OFF")
cora_irredundant_systems(minaret)[[1]]

## ----fig.alt = "Two-level logic diagram of the tort liability solution"-------
cora_logigram(cora_irredundant_sums(tort)[[1]])

## ----error = TRUE-------------------------------------------------------------
gapped <- data.frame(A = c(1, 1, 0, 0), B = c(2, 1, 2, 2),
                     OUT = c(1, 1, 0, 1))
cora_prime_implicants(cora_context(gapped, "OUT"))

## -----------------------------------------------------------------------------
fixed <- cora_recode(gapped, "B")
fixed

## -----------------------------------------------------------------------------
praet <- cora_context(bergschlosser, "PRAET",
                      input_labels = c("AGRPOP", "PARCL", "APROG",
                                       "PS", "RQ", "LRC"),
                      case_col = "Case", inc_score1 = 0.6,
                      algorithm = "ON-OFF")
length(cora_irredundant_sums(praet, max_depth = 7))

## -----------------------------------------------------------------------------
cora_data_mining(mccluskey, c("F1", "F2"), len_of_tuple = 2)

