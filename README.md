# CORA

CORA (Combinational Regularity Analysis) in R environment.

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

Combinational Regularity Analysis is a configurational comparative method. It
searches data for INUS structures - cause-effect relations marked by
conjunctivity (`a` **and** **not** `b` **and** `c`) and disjunctivity (`d`
**or** `e` **or** `f`) - using Boolean minimisation algorithms borrowed from
switching circuit analysis. Unlike related methods, CORA analyses structures
with simple as well as complex effects, and it handles multi-value conditions.

This package is an R port of the Python packages
[CORA](https://github.com/PoliUniLu/cora) and
[LOGIGRAM](https://github.com/PoliUniLu/logigram) by Zuzana Sebechlebská,
Lusine Mkrtchyan and Alrik Thiem. **It computes in plain R and requires no
Python installation.**

It is an independent implementation and is not endorsed by the authors of
the original packages. Anything it gets wrong by departing from the Python
implementation is this package's responsibility, not theirs.

## Installation

```r
# install.packages("remotes")
remotes::install_github("youngchanresearcher/CORA")
```

## Usage

```r
library(CORA)

df <- data.frame(A   = c(1, 0, 1, 0),
                 B   = c(1, 0, 0, 1),
                 C   = c(0, 1, 1, 0),
                 OUT = c(1, 1, 0, 1))

ctx <- cora_context(df, output_labels = "OUT")

cora_truth_table(ctx)        # the configurations the analysis works on
cora_prime_implicants(ctx)   # #A{0}, C{0}, B{1}
cora_irredundant_sums(ctx)   # M1: #A{0} + C{0} ; M2: #A{0} + B{1}
```

Every literal is printed as `CONDITION{value}`, so a term says outright which
value of a condition it stands for: `B{2}*D{0}` is B at 2 and D at 0. An
essential prime implicant is prefixed with `#`. The package does not use the
upper/lower case convention of the Python implementation, which marks a
negated literal by the presence of 0 in its value set and therefore says
nothing when a condition happens to be coded without a zero.

### Truth table construction

`cora_context()` aggregates the cases into configurations and decides which
of them count as positive:

| argument | meaning |
| --- | --- |
| `n_cut` | minimum number of cases below which a configuration is a don't care |
| `inc_score1` | minimum inclusion score for an output function value of 1 |
| `inc_score2`, `U` | the second inclusion cut-off and which value it applies to |
| `case_col` | column holding case identifiers |
| `algorithm` | `"ON-DC"` (Quine-McCluskey over positive and don't care terms) or `"ON-OFF"` (McCluskey's modified algorithm over positive and negative terms) |

Conditions must be coded from zero upwards, with no gaps: `0, 1, 2, ...`
The package refuses data that is coded otherwise and names the columns to
fix, as the other configurational packages in R do. `as.integer()` on a
factor numbers the levels from one, so this is easy to run into:

```r
df <- cora_recode(df, c("A", "B"))   # or cora_recode(df) to find them itself
```

### Multi-value conditions and complex effects

Outcome values that count as positive are declared in curly brackets. With
more than one outcome column the analysis returns irredundant *systems*
rather than sums:

```r
ctx <- cora_context(bergschlosser, c("AUTH{1}", "DEM{1}"),
                    input_labels = c("PS", "RQ", "LRC"),
                    case_col = "Case", inc_score1 = 0.6,
                    algorithm = "ON-OFF")
cora_irredundant_systems(ctx)
```

### Configurational data mining

`cora_data_mining()` scores every n-tuple of conditions, a configurational
version of Occam's razor:

```r
cora_data_mining(mccluskey, c("F1", "F2"), len_of_tuple = 2)
```

### Logic diagrams

`cora_logigram()` draws a solution, or any expression in disjunctive normal
form, as a two-level logic diagram:

```r
cora_logigram("A{1}*B{1}+C{0}<=>F")
cora_logigram(cora_irredundant_sums(ctx)[[1]])
```

The diagram reader still accepts the upper/lower case notation on input
(`"A*B+c*A+b<=>F"`), so expressions written by hand or taken from the Python
implementation can be drawn as they are.

## Function reference

| function | purpose |
| --- | --- |
| `cora_context()` | data and analytical choices |
| `cora_truth_table()` | configurations after aggregation and cut-offs |
| `cora_prime_implicants()` | Boolean minimisation |
| `cora_pi_chart()` | prime implicant chart |
| `cora_irredundant_sums()` | solutions, one outcome |
| `cora_irredundant_systems()` | solutions, several outcomes |
| `cora_petrick()` | Petrick's method on a coverage list |
| `cora_recode()` | map conditions onto `0, 1, 2, ...` |
| `cora_pi_details()`, `cora_system_details()`, `cora_solutions()` | summary tables |
| `cora_coverage_score()`, `cora_inclusion_score()` | sufficiency statistics |
| `cora_describe()`, `cora_dnf()` | textual renderings of a solution |
| `cora_logigram()` | two-level logic diagram |
| `cora_data_mining()` | configurational data mining |
| `cora_compare_python()` | optional cross-check against the Python package |

## Documentation

`inst/docs/manual_zh-TW.md` is a full manual in Traditional Chinese: the
theory behind the method, what goes in and what comes out, how to read the
notation and the scores, and the parameter choices that matter.
`inst/examples/getting-started.R` is the same ground as runnable code.

## Bundled data

`swiss_minaret`, `gross_carvin`, `mccluskey` and `bergschlosser`, all taken
from the examples of the Python CORA package.

## Relation to the Python implementation

The R results were checked configuration by configuration against the Python
package on its own test and example data: truth tables, prime implicants,
coverage sets and solution sets agree. Five differences are worth knowing,
and each of them is this package's own judgement rather than the original
authors':

* **Conditions that skip zero.** Data whose conditions are not coded
  `0, 1, 2, ...` is refused, with `cora_recode()` offered as the fix. The
  Python implementation accepts it and computes: its `"ON-OFF"` algorithm
  restores a free literal as `{0, ..., levels - 1}` and drops every row
  outside that set, so coverage sets come out short or empty, and the check
  deciding which outcomes a prime implicant refers to then succeeds
  vacuously on the empty set and assigns it every outcome. (This package
  also restores free literals from the values a condition actually takes,
  so the two algorithms agree once the coding is right.)
* **Notation.** Every literal is printed as `CONDITION{value}`. The Python
  implementation prints a binary literal in upper or lower case depending on
  whether 0 is in its value set, which distinguishes nothing when a condition
  is coded without a zero: `A` then stands for A's lower value and `B` for
  B's upper value, indistinguishably. Nothing in the computation changes;
  `#a + B` here reads `#A{0} + B{1}`. The diagram reader still accepts the
  case notation on input.
* **Solution order.** Solutions are returned in a deterministic order
  (shortest first, then lexicographic), so `M1` in R need not be `M1` in
  Python. The sets of solutions are the same.
* **Inclusion score of a prime implicant under `"ON-OFF"` with several
  outcomes.** The Python implementation evaluates such a prime implicant
  against *every* outcome column rather than against the outcomes the prime
  implicant refers to, which makes its score disagree with the one the same
  prime implicant receives under `"ON-DC"`. This package uses the prime
  implicant's own outcomes in both algorithms, so the two agree.
* **Tautologies in data mining.** A tuple of conditions whose only
  solution is the tautology `1` is reported by `cora_data_mining()` with
  zero solutions and zero scores. The Python implementation means to do
  the same, but its check never fires, so such a tuple is scored as
  though it explained the outcome.

`cora_compare_python()` runs a context through both implementations and
reports whether they agree; it needs `reticulate` and the Python package, and
nothing else in the package does.

## Citation

Cite this package, the method it implements, and the packages it was
adapted from. `citation("CORA")` prints all three entries:

> Chan, Y. (2026). *CORA: Combinational Regularity Analysis*. R package
> version 0.1.0.

> Thiem, A., Mkrtchyan, L., & Sebechlebská, Z. (2022). Combinational
> Regularity Analysis (CORA) - a new method for uncovering complex causation
> in medical and health research. *BMC Medical Research Methodology*, 22(1),
> 333.

> Sebechlebská, Z., Mkrtchyan, L., & Thiem, A. (2023). CORA and LOGIGRAM: A
> duo of Python packages for Combinational Regularity Analysis (CORA).
> *Journal of Open Source Software*, 8(85), 5019.

## License

GPL (>= 3), as required by the original implementation from which this
package is derived. See `inst/NOTICE` for attribution details.
