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
and solution memberships it compared are unaffected.

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
