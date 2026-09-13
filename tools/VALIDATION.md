# Cross-validation against the Python implementation

`tools/reference_py.py` and `tools/reference_r.R` run the same analyses
through the Python package and through this one and emit the same summary,
so that the two can be diffed. `tools/specs.json` holds the scenarios: the
worked examples of both READMEs, every data set in the Python package's
`tests/data` and `examples` directories under both algorithms, and the
data-mining examples.

Run them with the Python package importable and this package's `R/`
directory as the working directory:

```sh
python tools/reference_py.py tools/specs.json > py.json
Rscript tools/reference_r.R tools/specs.json > r.json
```

## Result

41 scenarios, 263 compared fields. Truth tables, prime implicants with their
outcome tags, coverage sets, solution sets and solution scores agree
everywhere, including the largest case (`Multi_output/data4.csv`: 39 prime
implicants over four outcomes, 1386 irredundant systems).

The comparison predates the change of notation, so re-running it now needs
the implicant strings mapped between the two conventions; the coverage sets
and solution memberships it compared are unaffected. The randomised
comparison below does that mapping and is the more thorough of the two.

Eight fields differ, all of them accounted for by the two deliberate
corrections documented in the README:

* `pi_scores` under `"ON-OFF"` with several outcomes, in seven scenarios.
  The Python implementation passes every outcome label to the prime
  implicant instead of the labels the prime implicant refers to, so its
  inclusion score disagrees with the score the same prime implicant gets
  under `"ON-DC"`. This package uses the prime implicant's own outcomes, so
  the two algorithms agree.
* `mining` in `mining_2tuple`. Tuples whose only solution is the tautology
  `1` score zero here. The Python implementation tests the solution against
  `"1"` after it has been marked essential and renamed to `"#1"`, so the
  test never fires and a vacuous tuple is scored as though it explained the
  outcome.

## Randomised differential testing

`tools/specs.json` fixes a set of scenarios. To test the parts of the input
space nobody chose, 200 random data sets were generated (2-4 conditions, 2-3
levels each, 1-2 outcomes, 5-11 rows, both algorithms, inclusion cut-offs of
0.5, 0.75 and 1) and run through both implementations.

Comparing implicant structure rather than implicant spelling, so that the
notation change does not count as a difference:

* **No structural difference at all.** Prime implicants, their outcome tags,
  coverage sets and solution sets agree on all 200 data sets.
* **35 data sets differ numerically, every one of them multi-outcome under
  `"ON-OFF"`** — the case the inclusion-score correction is about. Coverage
  scores agree everywhere; only inclusion differs.
* Those 35 data sets contain 87 disputed inclusion scores. Recomputing each
  one from the definition — among the cases the prime implicant covers, the
  share that show the outcome *that prime implicant is an implicant of* —
  matches this package in 87 of 87 and the Python implementation in none.

## Properties checked without a reference

`tests/testthat/test-properties.R` generates data the same way and checks
what has to be true of any correct answer, so the tests do not depend on
the Python package being installed:

* a solution covers every positive row of the truth table;
* no term of a solution can be dropped without losing a row (irredundance);
* a prime implicant covers positive rows only, and no two are identical;
* a prime implicant marked essential holds a row no other one reaches;
* coverage and inclusion scores are proportions;
* the two algorithms return the same terms whenever the data is coded from
  zero upwards.

All hold across the generated data sets.

## Regression check across the fixed scenarios

The Python implementation does not finish `specs.json` within fifteen minutes
— it is still working on `Multi_output/data4.csv` — so the fixes made after
the original comparison were checked a different way: the same driver was run
over `specs.json` on the code before and after them.

**41 scenarios, 251 compared fields, no field changed.** Three scenarios are
refused by both runs (the conditions are not coded from zero upwards), and
the remaining 38 produce byte-identical output. The fixes therefore change
nothing about the answer on input that was already being analysed; what they
change is which input is refused and how.

## Where the two implementations refuse different inputs

The drivers record a refusal per scenario instead of halting, because the
two do not accept the same inputs:

* Conditions not coded from zero upwards are refused here and analysed there
  (README difference 1). Three scenarios in `specs.json` are refused for this
  reason.
* A truth table emptied by `n_cut` returns no solution here. The Python
  implementation raises an internal pandas error instead (`KeyError`,
  `ValueError` or `IndexError`, depending on the shape of what is left). This
  showed up in 16 of 120 random data sets generated with `n_cut = 2`, and is
  why the randomised comparison above uses `n_cut = 1` throughout.

## Cost of ON-DC on a many-valued condition

`"ON-DC"` merges subsets of a condition's value set, so its cost grows
exponentially in the number of levels of a single condition. Measured on one
condition of *k* levels, second condition binary, outcome a threshold on the
first:

| levels | this package | Python |
|---|---|---|
| 12 | 0.32s | 0.06s |
| 14 | 1.7s | 0.21s |
| 16 | 7.6s | 1.05s |
| 18 | 36s | 5.9s |

Both roughly quintuple every two levels. The two columns were timed in
separate sessions on the same container, whose speed varies between them — an
earlier run of the same script gave 0.16s / 0.85s / 4.0s / 23s for this
package — so read the growth rate, which is a property of the algorithm, and
not the ratio between the columns, which is a property of the afternoon. `"ON-OFF"` returns the same prime implicants in
0.01s at every size, because it works from the observed rows rather than the
full configuration space. **Use `"ON-OFF"` for conditions with many levels.**
A condition of more than 30 levels is refused under `"ON-DC"`, which is the
width of the bit mask the reduction step uses; `"ON-OFF"` has no such limit.


## What 0.1.1 changed, and what it did not

Four behaviours were chosen for 0.1.1 around what happens when an analysis
gets large. Three of them change only what is refused or said out loud; one
changes how implicants are written.

Running the driver over `specs.json` on the code before and after: **41
scenarios, 251 compared fields, 225 byte-identical, 26 differing only in the
order literals are written inside a conjunction, none differing in content.**

* **`max_depth` bounds Petrick's method as it runs.** Pruning products longer
  than the bound as they are formed is exact, because a product never loses
  an implicant as multiplication continues. Checked against the old
  filter-afterwards route on randomly generated data: **386 single-outcome
  and 94 multi-outcome comparisons, no mismatch.** The difference is only
  ever speed:

  | `bergschlosser`, `PRAET`, ON-OFF | solutions | time |
  |---|---|---|
  | unrestricted | 74,524 | 24s |
  | `max_depth = 8` | 564 | 0.7s |
  | `max_depth = 7` | 21 | 0.2s |

  A three-outcome system over the same data (87 prime implicants) did not
  finish at all before; `max_depth = 7` returns in under a second.

  Bounding each outcome's own chart needed care: an outcome with prime
  implicants but no sum within the bound was at first dropped from the
  system, which built systems that left that outcome unexplained. The
  randomised comparison above is what caught it.

* **Literals are written in alphabetical order of the condition.** Previously
  they followed the order the columns sat in, so the same analysis printed
  `A{0}*C{1}` or `C{1}*A{0}` depending on how the data frame was assembled.

* **`"ON-DC"` warns above twelve levels on a condition**, and a run with more
  than ten thousand irredundant solutions says so.
  `cora_pi_details()` and `cora_solutions()` lay out the first 50 solutions
  unless asked for more, rather than building a table with tens of thousands
  of columns.

## A sixth defect in the Python implementation

`get_irredundant_sums(self, max_depth=None)` documents `max_depth` as "a
positive integer denoting max number of prime implicants in the solution".
Every value, `0` included, returns the full solution set.

The bound is not missing from the codebase, though. `cora/petric.py:21`
implements it, and correctly — as a search bound, the same design this
package uses:

```python
def _find_irredundant_sums(implicants_with_coverage, coverage, max_depth=None):
    if max_depth is None:
        max_depth = len(implicants_with_coverage)
    ...
    # If we reached maximal depth / maximal length of the sum, do not continue.
    if len(partial_solution) > max_depth:
        return
```

It is exported from `cora/__init__.py` and exercised by the package's own
`tests/test_petric.py`. What happened is a wiring break:
`get_irredundant_sums` calls the native C++ solver instead
(`prime_implicants.py:1067`), and that entry point takes two arguments with
no place for a bound (`petric.py:6`). When the faster solver was adopted the
parameter was left behind on the public method, documentation and all.

So this one is unlike the other five. Those are errors of logic or meaning;
this is a parameter dropped during an optimisation. The original authors knew
what the bound should do and implemented it correctly — that implementation
is simply unreachable from the documented method.
