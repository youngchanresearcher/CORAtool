## A tour of the package, following the examples of the Python original.
library(CORA)

## --------------------------------------------------- one binary outcome ----
df <- data.frame(A   = c(1, 0, 1, 0),
                 B   = c(1, 0, 0, 1),
                 C   = c(0, 1, 1, 0),
                 OUT = c(1, 1, 0, 1))

ctx <- cora_context(df, output_labels = "OUT")
cora_truth_table(ctx)
cora_prime_implicants(ctx)
cora_pi_chart(ctx)
cora_irredundant_sums(ctx)
cora_pi_details(ctx)
cora_solutions(ctx)

## ------------------------------------------- multi-value, one outcome ------
tort <- cora_context(gross_carvin, "TORT", case_col = "Case",
                     algorithm = "ON-OFF")
cora_prime_implicants(tort)
cora_irredundant_sums(tort)
cora_system_details(tort)

## ------------------------------------------------- several outcomes --------
minaret <- cora_context(swiss_minaret, c("X", "M"), algorithm = "ON-OFF")
cora_truth_table(minaret)
cora_irredundant_systems(minaret)
cora_solutions(minaret)

## ---------------------------------------------- configurational mining -----
cora_data_mining(mccluskey, c("F1", "F2"), len_of_tuple = 2)

## --------------------------------------------------- logic diagrams --------
cora_logigram(cora_irredundant_sums(ctx)[[1]])
cora_logigram("A{1}*B{2}+C{0}<=>F")
