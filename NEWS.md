# CORAtool 0.1.1

**The package is now called `CORAtool`.** CRAN carries a package named
`cora`, and CRAN compares package names without regard to case, so `CORA`
could not be submitted. Nothing else changed: every function keeps its
`cora_` prefix, so only the `library()` line in existing scripts needs
editing.

Fixes for defects found by adversarial and randomised testing, and four
choices about what to do when an analysis gets large.

Nothing here changes the answer on input that was already being analysed.
Across the 41 cross-validation scenarios, 225 of 251 compared fields are
byte-identical and the other 26 differ only in the order literals are written
inside a conjunction, which is a deliberate change listed below. What else
changes is which input is refused, and how.

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
* `max_depth` now bounds Petrick's method as it runs rather than filtering
  the finished list, which is often the difference between an answer and no
  answer: a chart of 46 prime implicants whose 74,524 solutions take 24
  seconds answers `max_depth = 7` in 0.2 seconds, and a three-outcome system
  over 87 prime implicants that never finished returns in under a second.
  Pruning is exact — a product never loses an implicant as multiplication
  continues — and `search = "exhaustive"` asks for the old route, which
  returns the same solutions and keeps each one's number in the unrestricted
  set. `cora_irredundant_systems()` takes both arguments too. The Python
  implementation documents the same parameter but every value, `0` included,
  returns the full solution set: the bound is implemented correctly in its
  `petric.py`, and was left behind on the public method when that method
  moved to the native solver.
* Literals inside a conjunction are written in alphabetical order of the
  condition instead of the order its column happens to sit in, so the same
  analysis prints the same string whichever way the data frame was assembled.
  Ordinary collation is used rather than a byte order, which keeps names
  outside ASCII working in any locale.
  This changes no result: of the 251 cross-validation fields, 225 are
  byte-identical and the other 26 differ only in that order.
* `"ON-DC"` warns when a condition has more than twelve levels. Its cost
  grows exponentially in the levels of a single condition — 23 seconds at
  eighteen, out of reach at thirty — while `"ON-OFF"` returns the same prime
  implicants in a fraction of a second at any size.
* A run with more than ten thousand irredundant solutions says so, and
  `cora_pi_details()` and `cora_solutions()` lay out the first 50 rather than
  building a table tens of thousands of columns wide. `max_solutions = Inf`
  asks for all of them.
* An outcome named among its own conditions is refused: it explains itself
  perfectly and says nothing about anything else.
* A case column naming no column in the data is refused rather than ignored,
  which used to drop the case labels silently; so are a case column of more
  than one name, one also named as a condition, repeated input or outcome
  names, empty or missing outcome names, and a `cov` outside [0, 1].
* Outcomes declared inconsistently — one with values in curly brackets, one
  without — now say so instead of reporting the declaration as a column name
  missing from the data.
* The extended manual now ships in English as well as Traditional Chinese,
  as `inst/docs/manual_en.md` and `inst/docs/manual_zh-TW.md`. Both carry the
  same nine sections and four appendices.
* A vignette, `vignette("cora")`, walks through an analysis in English: what
  the method looks for, the five stages, reading the scores, multi-value
  conditions, complex effects, diagrams, choosing an algorithm, the zero-based
  coding requirement, and what to do when there are more solutions than can be
  reported. The Traditional Chinese manual remains the fuller reference.
* `citation("CORAtool")` reports the installed version rather than a version
  string fixed when the file was written, and `inst/CITATION` is pure ASCII
  so it does not depend on an encoding being declared elsewhere.
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
