#' CORA: Combinational Regularity Analysis
#'
#' An R implementation of Combinational Regularity Analysis (CORA), a member
#' of the family of configurational comparative methods. CORA searches data
#' for INUS structures - cause-effect relations marked by conjunctivity and
#' disjunctivity - using Boolean minimisation algorithms borrowed from
#' switching circuit analysis. It handles multi-value conditions and, unlike
#' related methods, structures with simple as well as complex effects.
#'
#' The package is a port of the Python packages `CORA` and `LOGIGRAM` by
#' Sebechlebská, Mkrtchyan and Thiem. It computes in plain R and needs no
#' Python installation; [cora_python_available()] and the functions around it
#' exist only to cross-check results against the original implementation.
#'
#' @section Workflow:
#' Build a context with [cora_context()], inspect the truth table with
#' [cora_truth_table()], minimise it with [cora_prime_implicants()], and
#' solve the prime implicant chart with [cora_irredundant_sums()] (one
#' outcome) or [cora_irredundant_systems()] (several outcomes). Summaries are
#' available from [cora_pi_details()], [cora_system_details()] and
#' [cora_solutions()]; [cora_logigram()] draws the solution as a two-level
#' logic diagram.
#'
#' @references
#' Thiem, A., Mkrtchyan, L., and Sebechlebská, Z. (2023). Combinational
#' Regularity Analysis (CORA) - a new method for uncovering complex causation
#' in medical and health research. *BMC Medical Research Methodology*, 23, 279.
#' \doi{10.1186/s12874-023-02120-2}
#'
#' Sebechlebská, Z., Mkrtchyan, L., and Thiem, A. (2023). CORA: A Python
#' package for Combinational Regularity Analysis.
#'
#' @keywords internal
"_PACKAGE"
