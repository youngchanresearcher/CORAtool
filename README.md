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
the original packages. Where it goes wrong, including where it departs from
the Python implementation on purpose, the responsibility is this package's
and not theirs.

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
cora_prime_implicants(ctx)   # B, c, #a
cora_irredundant_sums(ctx)   # M1: #a + c ; M2: #a + B
```

A positive binary literal is printed in upper case, a negative one in lower
case, and an essential prime implicant is prefixed with `#`. A multi-value
literal carries its value in curly brackets, as in `B{2}*D{0}`.

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
cora_logigram("A*B+c*A+b<=>F")
cora_logigram(cora_irredundant_sums(ctx)[[1]])
```

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
| `cora_pi_details()`, `cora_system_details()`, `cora_solutions()` | summary tables |
| `cora_coverage_score()`, `cora_inclusion_score()` | sufficiency statistics |
| `cora_describe()`, `cora_dnf()` | textual renderings of a solution |
| `cora_logigram()` | two-level logic diagram |
| `cora_data_mining()` | configurational data mining |
| `cora_compare_python()` | optional cross-check against the Python package |

## Bundled data

`swiss_minaret`, `gross_carvin`, `mccluskey` and `bergschlosser`, all taken
from the examples of the Python CORA package.

## Relation to the Python implementation

The R results were checked configuration by configuration against the Python
package on its own test and example data: truth tables, prime implicants,
coverage sets and solution sets agree. Three differences are worth knowing,
and each of them is this package's own judgement rather than the original
authors':

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
