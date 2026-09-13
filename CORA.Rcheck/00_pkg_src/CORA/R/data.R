#' Swiss minaret referendum
#'
#' Cantonal data on the 2009 Swiss referendum on the construction of
#' minarets, used as the multi-outcome example of the CORA package.
#'
#' @format A data frame with 11 rows and 6 columns: the conditions `A`, `L`,
#'   `S` and `T`, and the outcomes `X` and `M`.
#' @source Shipped with the Python CORA package,
#'   <https://github.com/PoliUniLu/cora>.
#' @examples
#' ctx <- cora_context(swiss_minaret, c("X", "M"), algorithm = "ON-OFF")
#' cora_irredundant_systems(ctx)
"swiss_minaret"

#' Tort liability of highway authorities
#'
#' Multi-value data on tort claims against highway authorities, used as the
#' single-outcome example of the CORA package.
#'
#' @format A data frame with 18 rows: the case label `Case`, the conditions
#'   `PRIC`, `LENG`, `UPSI`, `DOSI`, `RISK`, `FRFL` and `MIMA`, and the
#'   outcome `TORT`.
#' @source Shipped with the Python CORA package,
#'   <https://github.com/PoliUniLu/cora>.
#' @examples
#' ctx <- cora_context(gross_carvin, "TORT", case_col = "Case")
#' cora_prime_implicants(ctx)
"gross_carvin"

#' McCluskey's two-output switching function
#'
#' The textbook two-output switching function used to illustrate
#' multi-output Boolean minimisation.
#'
#' @format A data frame with 16 rows: the conditions `A`, `B`, `C` and `D`,
#'   and the outcomes `F1` and `F2`.
#' @source Shipped with the Python CORA package,
#'   <https://github.com/PoliUniLu/cora>.
#' @examples
#' cora_data_mining(mccluskey, c("F1", "F2"), len_of_tuple = 2)
"mccluskey"

#' Berg-Schlosser and De Meur's praetorianism data
#'
#' Multi-value data on 48 African countries with three outcome columns,
#' `AUTH`, `DEM` and `PRAET`.
#'
#' @format A data frame with 48 rows: the case label `Case`, the conditions
#'   `AGRPOP`, `PARCL`, `APROG`, `PS`, `RQ` and `LRC`, and the outcomes
#'   `AUTH`, `DEM` and `PRAET`.
#' @source Shipped with the Python CORA package,
#'   <https://github.com/PoliUniLu/cora>.
#' @examples
#' ctx <- cora_context(bergschlosser, "PRAET",
#'                     input_labels = c("PS", "RQ", "LRC", "AUTH"),
#'                     inc_score1 = 0.6, case_col = "Case")
#' cora_irredundant_sums(ctx)
"bergschlosser"
