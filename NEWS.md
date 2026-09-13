# CORA 0.1.0

* First release: an R port of the Python packages CORA and LOGIGRAM.
* Truth table construction with frequency and inclusion cut-offs
  (`cora_context()`, `cora_truth_table()`).
* Boolean minimisation with the ON-DC and ON-OFF algorithms, for binary and
  multi-value conditions and for one or several outcomes
  (`cora_prime_implicants()`, `cora_pi_chart()`).
* Petrick's method and irredundant solutions (`cora_petrick()`,
  `cora_irredundant_sums()`, `cora_irredundant_systems()`).
* Sufficiency statistics and summary tables (`cora_coverage_score()`,
  `cora_inclusion_score()`, `cora_pi_details()`, `cora_system_details()`,
  `cora_solutions()`, `cora_describe()`).
* Configurational data mining (`cora_data_mining()`).
* `cora_recode()` maps conditions onto `0, 1, 2, ...`; data coded otherwise
  is refused with a message naming the columns to fix.
* Two-level logic diagrams (`cora_logigram()`, `cora_dnf()`), with the
  expression written above the drawing and, optionally, each gate labelled
  with the conjunction it forms (`title`, `subtitle`, `show_terms`).
* Optional cross-check against the Python implementation
  (`cora_python_available()`, `cora_compare_python()`).
* Example data sets `swiss_minaret`, `gross_carvin`, `mccluskey` and
  `bergschlosser`.
