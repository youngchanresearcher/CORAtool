# CORA 0.1.1

Fixes for defects found by adversarial and randomised testing. None of them
changes the answer on input that was already being analysed: the same 41
cross-validation scenarios produce byte-identical output before and after.
What changes is which input is refused, and how.

* `max_depth` was read after the solution cache, so a restriction asked for
  after an unrestricted call was ignored, and one asked for first was cached
  as though it were the whole solution set: `cora_pi_details()` then lost its
  `M` columns, `cora_solutions()` returned no rows, and
  `cora_system_details()` reported no solution at all. The cache now holds
  the unrestricted set and the restriction filters a copy on the way out.
  Solutions keep the number they have in the unrestricted set, so a
  restricted call can return `M2` and `M5`.
* A truth table emptied by `n_cut` no longer stops the multi-outcome
  `"ON-OFF"` path with `subscript out of bounds`; it returns no solution, as
  every other path already did.
* Duplicated column names are refused. Columns are addressed by name, so two
  columns sharing one silently dropped a condition, and a condition named
  like the outcome had the outcome read from the wrong column.
* Data with no rows is refused with a message about rows rather than about
  zero-based coding.
* `n_cut`, `inc_score1`, `inc_score2`, `U`, `len_of_tuple` and `max_depth`
  are checked. `NA` used to pass through to a comparison that is neither
  `TRUE` nor `FALSE`, and a fractional `len_of_tuple` reached `combn()`,
  which truncates it.
* `cora_logigram()` refuses a value too large to be a condition value, which
  became `NA` and drew the literal as though its condition had never been
  named, and a term that gives one condition two values, which silently kept
  the last.
* New property tests check what must hold of any correct output — coverage,
  irredundance, primality, essentiality, score ranges, and agreement between
  the two algorithms — over randomly generated data, without needing the
  Python package.

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
