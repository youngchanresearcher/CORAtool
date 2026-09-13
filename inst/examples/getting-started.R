## CORA: a runnable tour of the package.
##
## Every block here stands on its own. Run it top to bottom, or pick the
## section that matches what you need. See inst/docs/manual_zh-TW.md for the
## reasoning behind each step.

library(CORA)

## ---------------------------------------------------------------------------
## 1. One binary outcome
## ---------------------------------------------------------------------------

df <- data.frame(A   = c(1, 0, 1, 0),
                 B   = c(1, 0, 0, 1),
                 C   = c(0, 1, 1, 0),
                 OUT = c(1, 1, 0, 1))

ctx <- cora_context(df, output_labels = "OUT")

cora_truth_table(ctx)        # the configurations the analysis works on
cora_prime_implicants(ctx)   # #A{0}, C{0}, B{1}  ('#' marks an essential term)
cora_pi_chart(ctx)           # which term covers which positive row
cora_irredundant_sums(ctx)   # M1: #A{0} + C{0} ; M2: #A{0} + B{1}
cora_pi_details(ctx)         # coverage and inclusion of every term
cora_system_details(ctx)     # coverage and inclusion of the solution
cora_solutions(ctx)          # which terms belong to which solution

## Both solutions are valid. Report both: the data cannot separate them.
vapply(cora_irredundant_sums(ctx), cora_describe, character(1))

## ---------------------------------------------------------------------------
## 2. How the truth table is built
## ---------------------------------------------------------------------------

raw <- data.frame(ID = as.character(1:5),
                  A  = c(1, 1, 0, 1, 1),
                  B  = c(0, 1, 1, 1, 0),
                  C  = c(1, 1, 0, 1, 1),
                  O  = c(0, 0, 1, 1, 1))

## `raw = TRUE` shows the case count, the case labels and the raw inclusion
## score behind every configuration.
cora_truth_table(cora_context(raw, "O", case_col = "ID", inc_score1 = 0.5),
                 raw = TRUE)

## A stricter frequency cut-off drops configurations seen only once.
cora_truth_table(cora_context(raw, "O", case_col = "ID",
                              inc_score1 = 0.5, n_cut = 2), raw = TRUE)

## ---------------------------------------------------------------------------
## 3. Conditions have to be coded 0, 1, 2, ...
## ---------------------------------------------------------------------------

## as.integer() on a factor numbers the levels from one, which CORA refuses.
scale <- data.frame(size = as.integer(factor(c("s", "l", "m", "s"),
                                             levels = c("s", "m", "l"))),
                    B = c(0, 1, 1, 0),
                    OUT = c(1, 0, 1, 1))
range(scale$size)                    # 1 3  -- not what CORA expects
try(cora_prime_implicants(cora_context(scale, "OUT")))

scale <- cora_recode(scale, "size")  # or cora_recode(scale) to find them itself
range(scale$size)                    # 0 2
cora_prime_implicants(cora_context(scale, "OUT"))

## ---------------------------------------------------------------------------
## 4. Multi-value conditions
## ---------------------------------------------------------------------------

tort <- cora_context(gross_carvin, "TORT",
                     case_col = "Case", algorithm = "ON-OFF")

cora_prime_implicants(tort)
cora_irredundant_sums(tort)
cora_pi_details(tort)
cora_system_details(tort)

## ---------------------------------------------------------------------------
## 5. Complex effects: several outcomes at once
## ---------------------------------------------------------------------------

mn <- cora_context(swiss_minaret, c("X", "M"), algorithm = "ON-OFF")

cora_truth_table(mn)
cora_irredundant_systems(mn)
cora_solutions(mn)
cat(cora_describe(cora_irredundant_systems(mn)[[1]]), "\n")

## A multi-value outcome declares the values that count as positive.
bs <- cora_context(bergschlosser, "PRAET",
                   input_labels = c("PS", "RQ", "LRC", "AUTH"),
                   case_col = "Case", inc_score1 = 0.6)
cora_irredundant_sums(bs)

## ---------------------------------------------------------------------------
## 6. Configurational data mining
## ---------------------------------------------------------------------------

## Which pair of conditions already generates a solution?
cora_data_mining(mccluskey, c("F1", "F2"), len_of_tuple = 2)

## Widen the search automatically until something is found.
cora_data_mining(df, "OUT", len_of_tuple = 1, automatic = TRUE)

## ---------------------------------------------------------------------------
## 7. Logic diagrams
## ---------------------------------------------------------------------------

cora_logigram(cora_irredundant_sums(ctx)[[1]])
cora_logigram(cora_irredundant_systems(mn)[[1]])
cora_logigram("A{1}*B{2}+C{0}<=>F")   # also takes "A*b+C<=>F" and "A[1]*B[2]"

## Saving one to a file.
## png("figure.png", width = 1100, height = 720, res = 130)
## cora_logigram(cora_irredundant_sums(tort)[[1]],
##               color_and = "#f6d9c9", color_or = "#cfe3d4")
## dev.off()

## ---------------------------------------------------------------------------
## 8. Cross-checking against the Python implementation (optional)
## ---------------------------------------------------------------------------

if (cora_python_available()) {
  cora_compare_python(ctx)
}
