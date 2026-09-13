# CORAtool user manual

Combinational Regularity Analysis (CORA) — an R package

> The package is called `CORAtool` because CRAN already carries a package
> named `cora`. The method it implements is CORA, and every function keeps
> its `cora_` prefix.

---

## Contents

**Main text**

1. [What this package is for](#1-what-this-package-is-for) — the problem, INUS structures, relation to QCA and CNA
2. [Input: what the data must look like](#2-input-what-the-data-must-look-like) — format, coding rules, three ways to declare an outcome
3. [The analysis in five stages](#3-the-analysis-in-five-stages) — truth table → minimisation → chart → Petrick → statistics
4. [Reading the output](#4-reading-the-output) — notation, relations, **what to do with a result (§4.4)**
5. [Worked examples](#5-worked-examples) — four analyses, and **how to read a diagram (§5.5)**
6. [Function reference](#6-function-reference)
7. [Choosing parameters, and the traps](#7-choosing-parameters-and-the-traps) — `n_cut`, `inc_score1`, **zero-based coding (§7.4)**
8. [Differences from the Python implementation](#8-differences-from-the-python-implementation)
9. [Citation and licence](#9-citation-and-licence)

**Appendices**

- [Appendix A: six defects in the Python implementation](#appendix-a-six-defects-in-the-python-implementation) — each with its source location and a reproducible example
- [Appendix B: how QCA, QCApro and cna do it](#appendix-b-how-qca-qcapro-and-cna-do-it) — three neighbouring packages, and the reasoning behind this one's choices
- [Appendix C: the bundled data sets carry no variable definitions](#appendix-c-the-bundled-data-sets-carry-no-variable-definitions)
- [Appendix D: authorship, citation and responsibility](#appendix-d-authorship-citation-and-responsibility)

> Just want it running: read §5.1, then §4.4.
> Writing it up: §4.4 step five lists the six things a paper has to state.
> Comparing against the Python package: Appendix A.

---

## 1. What this package is for

### 1.1 The question regression cannot answer

Most quantitative methods ask **how much each variable contributes on
average**. A regression coefficient estimates each condition's effect
separately, which assumes the conditions add up.

A great deal of causal structure in the social sciences and in medicine is
not shaped that way. It is shaped like this:

> The outcome occurs because "A is present **and** B is absent **and** C is
> present", **or** because "D is present **and** E is present".

In a structure like that, asking what "the effect of A" is has no answer: A
does nothing except alongside an absent B and a present C. This is
**configurational causation**, and it has two marks:

- **Conjunctivity** — several conditions must hold together to constitute a
  cause.
- **Disjunctivity** — the same outcome can be reached by several different
  routes.

CORA exists to identify structures of this kind.

### 1.2 INUS structures

Philosophy calls this an **INUS condition** (Mackie 1965):

> an **I**nsufficient but **N**ecessary part of an **U**nnecessary but
> **S**ufficient condition

Taking `A*b*C + D*E => Y` apart:

| Term | Here | Meaning |
|---|---|---|
| **I**nsufficient | `A` alone does not produce `Y` | A is not enough by itself |
| **N**ecessary part | `A` cannot be dropped from `A*b*C` | remove A and that route fails |
| **U**nnecessary | `A*b*C` is not the only route to `Y` | there is also `D*E` |
| **S**ufficient | `A*b*C` holding is enough for `Y` | that route stands on its own |

What CORA returns is an expression of exactly this form.

### 1.3 Relation to QCA and CNA

CORA belongs to the family of **configurational comparative methods** (CCM),
alongside QCA (Ragin 1987) and CNA (Baumgartner 2009). All three look for
INUS structures.

They differ in where they start. QCA comes from set theory and qualitative
comparison, CNA from the regularity theory of causation, and **CORA from
switching circuit analysis** — the branch of electrical engineering that
handles Boolean logic circuits.

That is not a coincidence. Propositional logic (the language of INUS
causation) and switching algebra (the language of circuits) are two branches
of the same Boolean algebra and are operationally equivalent. One of the
earliest Boolean optimisation algorithms — Quine-McCluskey — was arrived at
independently by an analytic philosopher (Quine) and an electrical engineer
(McCluskey).

**What CORA can do that QCA and CNA cannot:**

1. **Complex effects.** CORA is currently the only CCM that analyses simple
   and complex effects alike. A complex effect is an outcome that is itself a
   combination of outcome variables ("`y` and not `z`", "`y` and `z`").
2. **Multi-value conditions.** Conditions are not restricted to 0/1; they may
   be 0/1/2/… (Mkrtchyan et al. 2023).
3. **Configurational data mining.** Enumerate every combination of n
   conditions and find the fewest conditions that still generate a solution —
   a configurational Occam's razor.
4. **Logic diagrams (LOGIGRAM).** Draw the solution as a two-level logic
   diagram, which expresses and reads better than the Venn diagrams QCA
   commonly uses (Thiem et al. 2023).

---

## 2. Input: what the data must look like

### 2.1 The basic shape

A data frame, **one row per case**:

| Kind of column | What it holds | Required |
|---|---|---|
| Conditions | the explanatory side, coded as integers | yes |
| Outcomes | the outcome side, one or several columns | yes |
| Case column | case identifiers | no |

```r
df <- data.frame(
  A   = c(1, 0, 1, 0),
  B   = c(1, 0, 0, 1),
  C   = c(0, 1, 1, 0),
  OUT = c(1, 1, 0, 1)
)
```

### 2.2 Coding rules (important)

**Conditions must be non-negative integers counted from zero.**

- Binary: `0` = absent/low, `1` = present/high
- Multi-value: `0`, `1`, `2`, …

Fractions, `NA` and strings are refused. **A constant column is refused** —
a condition every case shares carries no discriminating information.

**"From zero, with no gaps" is a hard requirement, and data coded otherwise
is refused rather than analysed.** A condition coded `{1, 2}` instead of
`{0, 1}` makes the `"ON-OFF"` algorithm produce wrong numbers (§7.4), so the
package declines and tells you how to fix it:

```
Condition(s) 'B' are not coded from 0 upwards. CORA expects each condition
to take the values 0, 1, 2, ... with no gaps.
  Recode them with:  data <- cora_recode(data, c("B"))
```

Do as it says:

```r
df <- cora_recode(df, c("B"))   # or cora_recode(df) to let it find them
```

`cora_recode()` maps each condition onto `0, 1, 2, ...`, **keeping the order
of its values**, and leaves the outcome columns alone.

The most common source of the problem is `as.integer(factor(...))`, because
R counts factor levels from 1:

```r
as.integer(factor(c("low", "mid", "high"),
                  levels = c("low", "mid", "high")))   # 1 2 3  wrong
```

| Coding | Verdict |
|---|---|
| `0,1` · `0,1,2` · `0,1,2,3,4,5,6` | fine — any number of values |
| `1,2` · `1,2,3` | no zero |
| `0,2` · `0,1,3` | a gap |

```r
# each of these is refused
data.frame(A = c(1, 1, 1, 1), ...)   # constant
data.frame(A = c(1, NA, 1, 0), ...)  # missing
data.frame(A = c(1, 0.5, 1, 0), ...) # fractional
```

### 2.3 Three ways to declare an outcome

```r
# (1) the outcome is already 0/1
cora_context(df, output_labels = "OUT")

# (2) the outcome is multi-value: say which values count as positive
cora_context(df, output_labels = "OUT{1,2}")   # 1 or 2 -> positive

# (3) complex effects: several outcome columns analysed together
cora_context(df, output_labels = c("X", "M"))
cora_context(df, output_labels = c("OUT1{1,2}", "OUT2{1}"))
```

Form (2) is how CORA handles a multi-value outcome: the values named in the
brackets become 1 and the rest become 0.

Either every outcome declares its values or none of them does. Mixing the two
is refused, because a declaration cannot then be told apart from a column
name.

---

## 3. The analysis in five stages

```
raw data
   │
   │  ① aggregate into configurations, apply the thresholds
   ▼
truth table
   │
   │  ② Boolean minimisation (ON-DC or ON-OFF)
   ▼
prime implicants
   │
   │  ③ build the coverage matrix
   ▼
prime implicant chart
   │
   │  ④ solve with Petrick's method
   ▼
irredundant solutions
   │
   │  ⑤ compute the sufficiency statistics
   ▼
coverage / inclusion
```

### Stage ① Building the truth table

Several cases may share one combination of condition values. This stage
aggregates them into a **configuration** and decides whether that
configuration counts as positive.

```r
raw <- data.frame(
  ID = as.character(1:5),
  A  = c(1, 1, 0, 1, 1),
  B  = c(0, 1, 1, 1, 0),
  C  = c(1, 1, 0, 1, 1),
  O  = c(0, 0, 1, 1, 1)
)
cora_truth_table(cora_context(raw, "O", case_col = "ID", inc_score1 = 0.5),
                 raw = TRUE)
```

```
  A B C n Cases Inc_O O
1 0 1 0 1     3   1.0 1
2 1 0 1 2   1,5   0.5 1
3 1 1 1 2   2,4   0.5 1
```

- `n` — how many cases fall in this configuration
- `Cases` — which ones
- `Inc_O` — the share of them showing the outcome (the **raw inclusion score**)
- `O` — the outcome value after the thresholds are applied

**The four parameters that govern this stage:**

| Parameter | Effect | Default |
|---|---|---|
| `n_cut` | configurations held by fewer cases become don't cares and leave the table | `1` |
| `inc_score1` | `Inc` must reach this to count as 1 | `1` |
| `inc_score2` | the second, lower threshold | `NULL` |
| `U` | decides the band between them; must be 0 or 1 | `NULL` |

**How `inc_score2` and `U` work together.** With `inc_score1` alone there is
a single threshold. Given `inc_score2` (lower) as well as `inc_score1`
(higher), configurations landing between them are in an uncertain band:

- `U = 1` → the band counts as **1** (permissive, included)
- `U = 0` → the band counts as **0** (strict, excluded)

Giving `inc_score2` without `U` is an error.

### Stage ② Boolean minimisation

Reduce the truth table to **prime implicants** — combinations that cannot be
shortened any further.

```r
ctx <- cora_context(df, "OUT")
cora_prime_implicants(ctx)
#> #A{0}, C{0}, B{1}
```

**Two algorithms** (the `algorithm` argument):

| | `"ON-DC"` (default) | `"ON-OFF"` |
|---|---|---|
| In full | positives + don't cares | positives + negatives |
| Origin | classical Quine-McCluskey | McCluskey's modified algorithm |
| Method | expand the full configuration space, drop the negatives, minimise | compare each positive against every negative directly |
| Cost | slower with many conditions (the space grows exponentially) | works from the observed rows only, usually faster |

**Practical advice: use `"ON-OFF"` when there are many conditions, or when
one condition takes many values.** On correctly coded data the two algorithms
return the same prime implicants and the same solutions — verified on ten
paired binary data sets, the multi-value examples, and forty randomly
generated data sets (`tests/testthat/test-properties.R`). Incorrectly coded
data is refused before this stage (§7.4) and never reaches it.

**Why ON-DC gets slow.** It merges **every subset of a condition's value
set**, so its cost grows exponentially in the **number of levels of a single
condition**. Measured with a first condition of k levels and a binary second:

| Levels on that condition | ON-DC | ON-OFF |
|---|---|---|
| 12 | 0.16s | 0.01s |
| 14 | 0.85s | 0.01s |
| 16 | 4.0s | 0.01s |
| 18 | 23s | 0.01s |
| 30 | does not finish | 0.01s |

Roughly five times longer for every two levels. **Both find exactly the same
prime implicants** — the difference is that ON-DC expands the whole
configuration space while ON-OFF uses only the rows actually observed. Above
twelve levels the package warns and says so.

> The Python implementation grows the same way (5.9s at eighteen levels), so
> this is the algorithm rather than the port. This package is about four
> times slower in absolute terms.
>
> A condition of more than 30 levels is refused under `"ON-DC"` — that is the
> width of the bit mask the reduction step uses. `"ON-OFF"` has no such
> limit.

### Stage ③ The prime implicant chart

Which prime implicant covers which row of the truth table:

```r
cora_pi_chart(ctx)
#>       0 1 3
#> #A{0} 1 1 0
#> C{0}  0 1 1
#> B{1}  0 1 1
```

The column names are the positive rows of the truth table, numbered from 0.
`#A{0}` covers rows 0 and 1; `C{0}` and `B{1}` each cover rows 1 and 3.

Row 0 is covered by `#A{0}` alone, which makes `#A{0}` an **essential prime
implicant**: every solution must contain it. That is what the `#` prefix
means.

### Stage ④ Solving with Petrick's method

Find every **irredundant solution** — every combination of prime implicants
that covers all the positive rows and stops covering them all if any one term
is removed.

```r
cora_irredundant_sums(ctx)
#> M1: #A{0} + C{0}
#> M2: #A{0} + B{1}
```

**Both solutions are equally valid.** This is **model ambiguity**, a normal
feature of configurational methods rather than an error: the data does not
contain enough information to choose between them. The honest course is to
report both.

> The number of solutions can grow exponentially with the size of the chart.
> `max_depth` restricts how many prime implicants a solution may contain, and
> restricts the search rather than the finished list — see §7.3.1.

### Stage ⑤ Sufficiency statistics

```r
cora_pi_details(ctx)
#>      PI Cov.r Inc.   M1   M2
#> 1 #A{0}  0.67    1 0.33 0.33
#> 2  C{0}  0.67    1 0.33   NA
#> 3  B{1}  0.67    1   NA 0.33

cora_system_details(ctx)
#>                  Cov. Inc.
#> Solution details    1    1
```

| Column | Definition |
|---|---|
| `Cov.r` | **coverage score**: of all cases showing the outcome, the share this prime implicant covers |
| `Inc.` | **inclusion score**: of the cases this prime implicant covers, the share showing the outcome |
| `M1`, `M2`, … | within that solution, the share of positive cases **only this term** covers |
| `NA` | this prime implicant is not in that solution |

**How to read the two scores:**

- **High inclusion** — when this combination holds, the outcome nearly always
  follows → close to a **sufficient condition**
- **High coverage** — most cases showing the outcome are covered by it →
  strong explanatory reach, close to a **necessary condition**

They answer different questions and neither substitutes for the other. A term
with inclusion 1 and coverage 0.05 is saying "whenever it appears the outcome
follows, but it accounts for 5% of the cases".

---

## 4. Reading the output

### 4.1 Notation

| Symbol | Meaning | Example |
|---|---|---|
| `X{v}` | condition X takes the value v | `A{0}`, `LENG{2}` |
| `*` | logical product (AND, conjunction) | `A{1}*B{0}*C{1}` |
| `+` | logical sum (OR, disjunction) | `A{1}*B{0} + C{1}` |
| `#` prefix | essential prime implicant | `#A{0}` |
| `1` | tautology — every observed configuration is positive | `M1: #1` |

**Every literal states its value explicitly**, binary conditions included:
`A{1}` is "A is 1" and `A{0}` is "A is 0".

The Python implementation writes case instead (upper = 1, lower = 0). This
package does not; the reasoning is in §8. In short: the case is decided by
whether 0 is in the value set, so a condition coded `{1, 2}` has no 0 in the
data, every literal prints upper case, and two different literals become
indistinguishable. `X{v}` is unambiguous however the condition is coded.

(`cora_logigram()` still *accepts* case notation as input, so an expression
written by hand or taken from the Python implementation can be drawn as it
is.)

Literals inside a conjunction are written in alphabetical order of the
condition, not in the order the columns sit in, so the same analysis prints
the same string however the data frame was assembled.

So `#LENG{2}*RISK{1} + #DOSI{1} + PRIC{0}` reads:

> "LENG is 2 **and** RISK is 1", **or** "DOSI is 1", **or** "PRIC is 0"

The first two terms are essential. Binary conditions read the same way:
`#A{0} + B{1}` is "A is 0" **or** "B is 1".

### 4.2 Relations

`cora_describe()` turns the scores into a statement of relation:

```r
cora_describe(cora_irredundant_sums(ctx)[[1]])
#> "#A{0} + C{0} <=> OUT"
```

| Symbol | Meaning | Condition |
|---|---|---|
| `=>` | sufficient | inclusion ≥ threshold and ≥ 0.5 |
| `<=` | necessary | coverage ≥ the `cov` argument and ≥ 0.5 |
| `<=>` | both | both hold |
| `Warning!` | neither | the solution does not stand up statistically |

`cov` defaults to 1 and can be relaxed: `cora_describe(sol, cov = 0.8)`.

### 4.3 Output for complex effects

A multi-outcome analysis returns **irredundant systems**, each carrying one
function per outcome:

```r
mn <- cora_context(swiss_minaret, c("X", "M"), algorithm = "ON-OFF")
cora_irredundant_systems(mn)
#> ---- System 1 ----
#> X: L{0}*T{0} + S{1}
#> M: L{0}*T{0} + S{1} + T{1}
```

> An individual function inside a system need not be irredundant, but **the
> system as a whole always is**. This is the heart of how CORA handles
> complex effects: it optimises all the outcomes together rather than running
> them separately and stapling the results together.

### 4.4 What to do with a result: reading it, and writing it up

`cora_solutions(ctx)` hands you a table. The table will not tell you which
solution is right — **that part is your job, not the software's**. Read it in
this order.

#### Step one: how many solutions are there?

```r
length(cora_irredundant_sums(ctx))
#> [1] 2
```

Two or more is **model ambiguity**, and it means something quite definite:

> On this data these solutions are **equally good**. No statistic can
> separate them, because they make identical predictions on every
> configuration that was observed.

They differ only on configurations that were **not** observed. Therefore:

- **Report all of them.** Picking one for the paper is a choice made where
  the reader cannot see it.
- Narrowing to one requires **theory or design** from outside the data (a
  combination that cannot occur, say), not more analysis. The data is spent.
- §5.2 is the standard case: two solutions differing only in whether the
  third term is `PRIC{0}` or `FRFL{0}*MIMA{0}`, with identical coverage and
  inclusion.

#### Step two: do the overall scores hold up?

```r
cora_system_details(ctx)
#>                  Cov. Inc.
#> Solution details    1    1
```

- **Low Inc.** — the solution misfires. There are cases where the conditions
  hold and the outcome does not follow.
- **Low Cov.** — the solution misses a lot. Most cases showing the outcome
  are not reached by it.

`Inc. = 1, Cov. = 1` looks perfect, but on a small sample it is **the norm
rather than an achievement** — few configurations are easy to separate
cleanly. The question that matters is the next one.

#### Step three: how much does each term carry?

```r
cora_pi_details(ctx)
#>      PI Cov.r Inc.   M1   M2
#> 1 #A{0}  0.67    1 0.33 0.33
#> 2  C{0}  0.67    1 0.33   NA
#> 3  B{1}  0.67    1   NA 0.33
```

- `Cov.r` and `Inc.` are the term's **own** scores, independent of which
  solution it sits in.
- The `M1`, `M2` columns are **unique coverage**: the share of positive cases
  that only this term covers, within that solution.
  - **High** — the term is irreplaceable; drop it and cases go uncovered.
  - **Zero** — everything it covers is covered by other terms too. It is in
    the solution because removing it would break irredundance, not because it
    holds any case of its own. Interpret with care.
  - **`NA` means the term is not in that solution**, not that the number
    could not be computed.
- A `#` prefix marks an **essential prime implicant**: it holds at least one
  positive case no other term reaches, so **every** solution contains it.
  This is the common core of all the solutions and the part most worth
  putting in a conclusion.

#### Step four: if Inc. is `NaN`

`NaN` appears when **the denominator is zero**: the prime implicant covers no
case at all. On sound data this does not happen. If it does, the usual causes
are a coding problem (§7.4) or an `n_cut` set high enough to filter every
configuration away.

#### Step five: writing it up

A CORA result somebody else could reproduce has to state at least:

| What to state | Why |
|---|---|
| `algorithm` (ON-DC or ON-OFF) | they assume different things about unobserved configurations, and may differ |
| `n_cut` and `inc_score1` | these decide directly which configurations count as positive |
| the coding of each condition and what each value means | `LENG{2}` means nothing unless the reader knows what 2 stands for |
| **every** solution, not one of them | see step one |
| Cov., Inc. and unique coverage | the three are only meaningful together |
| the degree of limited diversity | possible configurations vs. observed ones |

**The last point, and the most important one.** CORA finds **regularity
structure in the data**. "A is an INUS condition for B" is a statement about
the data, not about causation. Getting from regularity to causation needs
what the method cannot supply — theory, temporal order, a design that rules
out common causes. §1.2 said this; it is worth thinking about once more when
writing the conclusion.

---

## 5. Worked examples

### 5.1 Binary conditions, one outcome

```r
library(CORAtool)

df <- data.frame(A   = c(1, 0, 1, 0),
                 B   = c(1, 0, 0, 1),
                 C   = c(0, 1, 1, 0),
                 OUT = c(1, 1, 0, 1))

ctx <- cora_context(df, output_labels = "OUT")

cora_truth_table(ctx)        # the truth table
cora_prime_implicants(ctx)   # #A{0}, C{0}, B{1}
cora_pi_chart(ctx)           # the coverage matrix
cora_irredundant_sums(ctx)   # M1: #A{0} + C{0} ; M2: #A{0} + B{1}
cora_pi_details(ctx)         # per-implicant statistics
cora_system_details(ctx)     # per-solution statistics
cora_solutions(ctx)          # the summary table
```

### 5.2 Multi-value conditions, one outcome

`gross_carvin`: 18 tort liability cases against highway authorities, seven
multi-value conditions.

```r
tort <- cora_context(gross_carvin, "TORT",
                     case_col = "Case", algorithm = "ON-OFF")

cora_prime_implicants(tort)
#> LENG{0}*UPSI{0}, LENG{0}*RISK{0}, FRFL{0}*LENG{1}*RISK{0},
#> LENG{0}*MIMA{0}, #LENG{2}*RISK{1}, PRIC{0}, FRFL{0}*MIMA{0}, #DOSI{1}

cora_irredundant_sums(tort)
#> M1: #LENG{2}*RISK{1} + #DOSI{1} + PRIC{0}
#> M2: #LENG{2}*RISK{1} + #DOSI{1} + FRFL{0}*MIMA{0}

cora_system_details(tort)
#>                  Cov. Inc.
#> Solution details    1    1
```

Both solutions cover everything (Cov. = 1) and include everything
(Inc. = 1). They differ only in the third term: `PRIC{0}` or
`FRFL{0}*MIMA{0}`. The data cannot tell them apart.

### 5.3 Complex effects

`swiss_minaret`: 11 configurations, two outcome columns `X` and `M`.

```r
mn <- cora_context(swiss_minaret, c("X", "M"), algorithm = "ON-OFF")

cora_irredundant_systems(mn)
#> ---- System 1 ----
#> X: L{0}*T{0} + S{1}
#> M: L{0}*T{0} + S{1} + T{1}

cora_solutions(mn)
#>   L{0}*T{0} S{1} A{1}*T{0} A{1}*L{1} L{0} T{1} A{1} Output System
#> 1         1    1         0         0    0    0    0      X      1
#> 2         1    1         0         0    0    1    0      M      1

cat(cora_describe(cora_irredundant_systems(mn)[[1]]))
#> ---- System 1 ----
#> L{0}*T{0} + S{1} <=> X
#> L{0}*T{0} + S{1} + T{1} <=> M
```

`X` and `M` share the two routes `L{0}*T{0}` and `S{1}`; `M` has `T{1}` as
well.

### 5.4 Configurational data mining

The question: **how few conditions still generate a solution?**

```r
cora_data_mining(mccluskey, c("F1", "F2"), len_of_tuple = 2)
#>   Combination Nr_of_systems Inc_score Cov_score Score
#> 1        A, B             1         1     0.333 0.333
#> 2        A, C             1         1     0.667 0.667
#> 3        A, D             1         1     0.333 0.333
#> 4        B, C             1         1     0.667 0.667
#> 5        B, D             1         1     0.333 0.333
#> 6        C, D             1         1     0.667 0.667
```

`Score` is `Inc_score × Cov_score`, a single number for ranking. Here `A,C`,
`B,C` and `C,D` tie for best.

`automatic = TRUE` widens the search from `len_of_tuple` upwards until a
combination yields a non-empty solution:

```r
cora_data_mining(df, "OUT", len_of_tuple = 1, automatic = TRUE)
```

> **Note**: a combination whose only solution is the tautology `1` is scored
> as no solutions and zero. Every observed configuration is positive there,
> so it explains nothing.

### 5.5 Logic diagrams

A logigram draws the solution as a circuit. It adds no information — what is
on the diagram is in the expression — but it makes "which conditions act
together and which go their own way" visible at a glance.

```r
tort <- cora_context(gross_carvin, "TORT",
                     case_col = "Case", algorithm = "ON-OFF")
sol <- cora_irredundant_sums(tort)[[1]]

cora_logigram(sol)
```

The drawing carries these two lines above it:

```
#LENG{2}*RISK{1} + #DOSI{1} + PRIC{0}  <=>  TORT
M1    Cov. = 1.000    Inc. = 1.000    (# essential)
```

**The expression and the picture are two ways of writing the same thing**;
having both in one figure saves looking back and forth.

#### 5.5.1 Reading the diagram

Walk it left to right:

1. **The vertical lines are condition buses**, one per condition, named at the
   top.
   - Only conditions **that appear in this solution** get a bus.
   `gross_carvin` has seven conditions; the diagram above draws four, because
   `UPSI`, `FRFL` and `MIMA` are not in M1.
   - They are ordered **alphabetically**, not by column order.
2. **A filled dot on a bus is a tap**, and the `{v}` beside it is the value
   taken.
   - The dot marked `{2}` on the `LENG` bus is the literal "LENG equals 2".
   - One bus can carry several dots (different terms taking different
     values); they have nothing to do with each other.
3. **The yellow block (rounded on the right) is an AND gate**, combining the
   literals wired into it into one conjunction.
   - The AND gate above takes `LENG{2}` and `RISK{1}`, and outputs
     `LENG{2}*RISK{1}`.
   - **A term of a single literal gets no AND gate** — there is nothing to
     combine, and the line runs straight to the OR gate. `DOSI{1}` and
     `PRIC{0}` are like that, which is why the diagram has one AND gate while
     the expression has three terms. Do not read the number of gates as the
     number of terms.
4. **The blue shield is the OR gate**, combining the terms into a
   disjunction. Any one term holding makes the output hold.
5. **The name on the far right is the outcome column.**

So the diagram reads:

> "LENG is 2 **and** RISK is 1", **or** "DOSI is 1", **or** "PRIC is 0" — any
> one of the three routes going through means TORT occurs.

#### 5.5.2 Diagrams from case notation

`cora_logigram()` still accepts the Python implementation's case notation as
**input** (upper = 1, lower = 0). A negated literal is then drawn as a small
open circle on the line — a **bubble**, the standard circuit notation for
inversion:

```r
cora_logigram("A*B+c*A+b<=>F")                    # c and b get bubbles
cora_logigram("a'*b+c<=>F", notation = "prime")   # apostrophe notation
```

> Input for `notation = "prime"` **must be entirely lower case**, with
> negation written as a trailing apostrophe (`a'` is "a is 0"). Mixing case
> raises `Invalid input entered!`, because upper case could then be either
> "value 1" or a variable name that has not had its apostrophe added.

Multi-value expressions written as `X{v}` get no bubbles — `{0}` already says
the value, and an inversion symbol on top of it would be redundant.

#### 5.5.3 Diagrams with several outcomes

```r
mn <- cora_context(swiss_minaret, c("X", "M"), algorithm = "ON-OFF")
cora_logigram(cora_irredundant_systems(mn)[[1]])
```

- Each outcome gets its own OR gate, **stacked top to bottom in the order the
  outcomes were declared**.
- **A shared term is drawn once**, its output line branching into several OR
  gates. Above, the lines from `L{0}*T{0}` and `S{1}` each split in two, one
  going to `X` and one to `M`; `T{1}` feeds only `M`.
- This is exactly the point of analysing complex effects: **which mechanisms
  are shared between outcomes and which belong to one of them** is visible
  directly on the diagram, where in the expressions it means comparing two
  lines of text.

#### 5.5.4 Annotation and layout

| Argument | Effect |
|---|---|
| `title` | the expression above the drawing. `NULL` (default) prints the solution itself, `#` markers included; `NA` prints nothing; a character vector prints one line each |
| `subtitle` | the line under it. `NULL` (default) prints `Cov.` and `Inc.` for a solution object; `NA` prints nothing |
| `show_terms` | `TRUE` labels each gate with the conjunction it forms |
| `color_and` | fill colour of the AND gates |
| `color_or` | fill colour of the OR gates |

```r
# default: the expression and the scores are both printed
cora_logigram(sol)

# label each gate with its term as well (useful for a slide)
cora_logigram(sol, show_terms = TRUE)

# no annotation at all, when the caption is written by hand
cora_logigram(sol, title = NA, subtitle = NA)

# your own title
cora_logigram(sol, title = "Figure 3: sufficient conditions for liability",
              subtitle = "N = 18, ON-OFF algorithm")

# other colours
cora_logigram(sol, color_and = "#f3aea0", color_or = "#aed49c")

# saving it
png("figure.png", 1300, 850, res = 140)
cora_logigram(sol)
dev.off()
```

The layout follows the annotation: when the title is wider than the drawing,
the canvas widens to the right rather than cutting the text.

An expression can be drawn directly, without running an analysis first:

```r
cora_logigram("A{1}*B{2}+C{0}<=>F")
cora_logigram(c("A{1}*B{2}+A{2}<=>F1", "A{1}+C{1}*B{2}<=>F2"))
cora_logigram("A[1]*B[2]+C[0]<=>F")     # the QCA package's square brackets
```

`cora_dnf()` turns a solution into that string form (the format
`cora_logigram()` reads; the `#` markers are dropped):

```r
cora_dnf(cora_irredundant_sums(ctx)[[1]])
#> "A{0}+C{0}<=>OUT"
```

> A tautology (`1<=>OUT`) has no two-level diagram. A tautological solution
> means **every observed configuration is positive**: nothing is
> distinguishing anything, and drawing it would produce a fake diagram with
> an input bus named "1". `cora_logigram()` refuses outright.

---

## 6. Function reference

| Function | Purpose |
|---|---|
| `cora_context()` | build the analytical context: data plus every choice |
| `cora_truth_table()` | the truth table (`raw = TRUE` adds case counts and raw scores) |
| `cora_prime_implicants()` | Boolean minimisation |
| `cora_pi_chart()` | the prime implicant chart (coverage matrix) |
| `cora_irredundant_sums()` | irredundant solutions (**one outcome**) |
| `cora_irredundant_systems()` | irredundant systems (**several outcomes**) |
| `cora_pi_details()` | statistics per prime implicant |
| `cora_system_details()` | statistics per solution |
| `cora_solutions()` | the solution summary table |
| `cora_coverage_score()` | coverage score (of an implicant or a solution) |
| `cora_inclusion_score()` | inclusion score (of an implicant or a solution) |
| `cora_describe()` | render a solution as `=>` / `<=` / `<=>` |
| `cora_dnf()` | render a solution as a DNF string |
| `cora_logigram()` | draw a two-level logic diagram |
| `cora_data_mining()` | configurational data mining |
| `cora_petrick()` | run Petrick's method on a coverage list directly |
| `cora_recode()` | map conditions onto `0, 1, 2, ...` |
| `cora_python_available()` | is the Python implementation reachable? |
| `cora_compare_python()` | cross-check against the Python implementation |

**Bundled data sets**: `swiss_minaret` (11 rows, several outcomes),
`gross_carvin` (18 rows, multi-value), `mccluskey` (16 rows, a two-output
switching function), `bergschlosser` (48 rows, multi-value, three outcomes).

> All four are taken unchanged from the Python implementation, and **upstream
> supplies no variable definitions** — column abbreviations only, with no
> account of what they stand for or what the values 0/1/2 mean. Good for
> learning the syntax and checking output, **not for substantive inference**.
> See Appendix C.

---

## 7. Choosing parameters, and the traps

### 7.1 Setting `n_cut`

`n_cut` is "how many cases a configuration needs before I believe it".

- `n_cut = 1` (default): every observed configuration is used
- `n_cut = 2` or more: only repeated configurations are used, which is more
  robust to measurement error but throws data away

On a small sample (N < 30) `n_cut = 1` is usually the only option.

### 7.2 Setting `inc_score1`

`inc_score1 = 1` requires **every** case in a configuration to show the
outcome, which is the strictest setting. Real data is rarely that clean, and
0.75–0.9 is common.

**Relaxing `inc_score1` makes more configurations count as positive, which
makes the solution simpler and less precise.** That trade-off belongs in the
write-up; it is not something to adjust quietly.

### 7.3 Common traps

| Trap | What it is |
|---|---|
| **Limited diversity** | k conditions give 2^k possible configurations (more with multi-value ones) and you will have observed a fraction. How much of the solution rests on unobserved configurations is yours to know. |
| **Model ambiguity** | When several solutions appear, **report all of them**. Reporting one is selective presentation. |
| **Treating coverage as a p-value** | These are not significance tests. There is no null hypothesis, and a high score is not statistical significance. |
| **Too many conditions** | The explanatory power of a CCM falls away quickly as conditions are added. Four to seven is the usual advice; beyond that, screen with `cora_data_mining()` first. |
| **Causal reading** | CORA finds regularity structure in data. A causal claim needs theory and design the method cannot supply. |
| **Conditions not coded from zero** | See §7.4. This package refuses; the Python implementation does not, and returns plausible-looking wrong numbers. |
| **Too many solutions** | Once there are many prime implicants the number of irredundant solutions grows exponentially (`bergschlosser` + `PRAET` has 74,524). **Every one is valid**, which is exactly the problem: nobody can report them all. Above ten thousand this package warns and suggests `max_depth`. |

### 7.3.1 When there are too many solutions: `max_depth`

`bergschlosser`'s `PRAET` (46 prime implicants) has **74,524 solutions**,
which take 24 seconds to enumerate; all three outcomes together (87 prime
implicants) does not finish at all.

Every one of those solutions is valid and equally supported by the data,
which is the problem: **nobody can report them all**. The thing to do is ask
a narrower question:

```r
ctx <- cora_context(bergschlosser, "PRAET",
                    input_labels = c("AGRPOP","PARCL","APROG","PS","RQ","LRC"),
                    case_col = "Case", inc_score1 = 0.6, algorithm = "ON-OFF")

cora_irredundant_sums(ctx, max_depth = 7)   # 21 solutions, 0.2s
```

| | Solutions | Time |
|---|---|---|
| unrestricted | 74,524 | 24s |
| `max_depth = 8` | 564 | 0.7s |
| `max_depth = 7` | 21 | 0.2s |
| `max_depth = 6` | 0 | 0.1s |

(`max_depth = 6` gives none because the shortest solution needs seven prime
implicants.)

**`max_depth` bounds the search rather than filtering the finished list.**
That is the difference between an answer and no answer. The pruning is exact
— a product never loses an implicant as multiplication continues, so nothing
dropped could have come back under the bound — so the result is identical to
filtering afterwards (480 comparisons on random data, no difference).

`search = "exhaustive"` takes the old route. Both return the same solutions;
they differ only in this:

- `"bounded"` (default): fast, and solutions are numbered from 1 within the
  restricted set
- `"exhaustive"`: slower, but each solution **keeps the number it has in the
  unrestricted set**, so a restricted call can return `M2` and `M5`

> The Python implementation's `max_depth` has **no effect at any value** (0
> included, which still returns every solution). That is not because it was
> never written: the pure-Python solver in `cora/petric.py` **implements the
> same pruning design correctly**; it simply was not wired through when the
> public method moved to the C++ solver. See Appendix A.6b.

---

### 7.4 Conditions must be coded from zero

Every condition must run `0, 1, 2, ...` with no gaps. `{1, 2}` will not do,
and neither will `{0, 2}`.

This is the one trap that makes the Python implementation **quietly produce
wrong numbers**. This package refuses instead, so you will not hit it — but
you need to know why.

**The cause.** When the `"ON-OFF"` algorithm turns a minimised result back
into a full combination of conditions, the conditions it does not care about
have to be filled in with a set of values. The Python implementation fills in
`{0, 1, ..., levels-1}` — **assuming the values start at zero**. For a
condition actually coded `{1, 2}`, `levels = 2` and the fill-in is `{0, 1}`:
a set containing a value never observed (0) and missing one that was (2).
Every case where that condition is 2 is then excluded from coverage.

Measured on the Python implementation's own README data, with `B` coded
`{1,2}`:

| Prime implicant | ON-DC Cov. | ON-OFF Cov. | ON-OFF Inc. |
|---|---|---|---|
| `A{1}` | 0.667 | **0.333** | 1 |
| `C{0}` | 0.333 | **0.000** | **NaN** |
| `#C{2}` | 0.333 | **0.000** | **NaN** |
| `D{1}` | 0.333 | **0.000** | **NaN** |

Same data, same prime implicant, different score purely from changing the
algorithm. The full derivation, the source locations and four related defects
are in **Appendix A**.

**What this package does — two layers:**

1. **It refuses to compute.** The check runs the first time anything is
   actually calculated (`cora_prime_implicants()`, `cora_truth_table()` and
   the rest, and `cora_data_mining()`), and says how to fix it:

   ```
   Condition(s) 'B' are not coded from 0 upwards. CORA expects each condition
   to take the values 0, 1, 2, ... with no gaps.
     Recode them with:  data <- cora_recode(data, c("B"))
     cora_recode() maps each condition onto 0, 1, 2, ... keeping the order of
     its values.
   ```

2. **The underlying cause is fixed too.** The fill-in uses the condition's
   **actually observed values**, not `{0, ..., levels-1}` — the approach the
   `cna` package takes (Appendix B.3). So even if the check were bypassed,
   the coverage sets would be right.

After `cora_recode(df, "B")`, this package's ON-DC and ON-OFF return
**identical** prime implicants, `Cov.r`, `Inc.` and unique coverage on the
same data (only the row order differs). Every 0.333 / 0.000 / NaN in the
ON-OFF column above disappears.

> **Recoding shifts the labels**: once `B` goes from `{1,2}` to `{0,1}`, the
> old `B{2}` is `B{1}`. The structure is identical; only the numeric labels
> follow the coding. Keep this in mind when comparing against literature that
> used the Python implementation.

**Why not just recode automatically?** Because that shifts the labels without
the user knowing — the `B{1}` quoted in a paper would not be the `B{1}` in
the codebook on the desk. Refusing costs one line of `cora_recode()`; getting
it wrong costs a paper. (How QCA and cna handle this is in Appendix B.)

---

## 8. Differences from the Python implementation

This package is a port of PoliUniLu's Python packages `CORA` and `LOGIGRAM`.
The port was compared against it field by field on its own tests and example
data: **truth tables, prime implicants, coverage sets and solution sets agree
throughout** (41 scenarios, 263 compared fields).

Seven deliberate differences:

1. **Data not coded from zero is refused.** Where a condition is not coded
   `0, 1, 2, ...` this package raises an error (and names `cora_recode()`);
   the Python implementation proceeds and returns wrong coverage sets and
   scores (§7.4). The underlying "don't care" domain also uses the actually
   observed values, so the two algorithms agree whenever the coding is right.
2. **Solution order.** This package sorts deterministically (shorter first,
   then lexicographically), so R's `M1` need not be Python's `M1`. **The set
   of solutions is the same.**
3. **Notation.** This package always writes `X{v}`; the Python implementation
   writes binary conditions as case. This **changes no computed result**, only
   what is printed — `#a + B` here is `#A{0} + B{1}`. The reason is that the
   case is decided by whether 0 is in the value set, which fails completely
   when a condition is not coded from zero (§7.4). `cora_logigram()` still
   accepts case notation as input.
4. **A prime implicant's inclusion score under ON-OFF with several
   outcomes.** The Python implementation computes it over **every** outcome
   column. The implicant object's own `outputs` field says it corresponds to
   one outcome while its `output_labels` field lists them all — the two
   contradict each other, and the class documentation says both are
   "corresponding to the implicant". This package uses the implicant's own
   outcome columns.
5. **Tautologies in data mining.** A combination whose only solution is `1`
   is scored as no solutions and zero here. The Python implementation intends
   the same, but its check can never fire.
6. **`max_depth` actually restricts.** This package prunes during the
   multiplication in Petrick's method, so it both restricts and makes the
   analysis finishable (§7.3.1). The Python implementation's `max_depth` has
   no effect at any value — the pruning is implemented correctly in
   `cora/petric.py` but was not wired to the public method (Appendix A.6b).
7. **Literal order.** This package **sorts** the literals inside a
   conjunction by condition name (`A{0}*C{1}`, whatever the column order);
   the Python implementation prints them in column order. This **changes no
   computed result**; it means the same analysis prints the same string every
   time.

All seven are this package's own judgements, not the original authors'.
**Appendix A gives the source location, a reproducible example and the full
derivation for each**; Appendix B compares the design with QCA, QCApro and
cna.

To check for yourself:

```r
if (cora_python_available()) {
  cora_compare_python(ctx)
}
```

That needs `reticulate` and the Python `cora` package. **The package itself
needs no Python at all.**

---

## 9. Citation and licence

```r
citation("CORAtool")
```

lists three entries: this package, the CORA method paper, and the paper for
the Python packages. **An analysis using CORA must cite the method paper**,
whichever software produced the results. The reasoning behind the author
roles is in Appendix D.

- Thiem, A., Mkrtchyan, L., & Sebechlebská, Z. (2022). Combinational
  Regularity Analysis (CORA) — a new method for uncovering complex causation
  in medical and health research. *BMC Medical Research Methodology*, 22(1),
  333.
- Sebechlebská, Z., Mkrtchyan, L., & Thiem, A. (2023). CORA and LOGIGRAM: A
  duo of Python packages for Combinational Regularity Analysis (CORA).
  *Journal of Open Source Software*, 8(85), 5019.

Licence: GPL (>= 3), the same as the original implementation. This package is
an independent implementation and is not endorsed by the authors of the
original packages.

---

## Appendix A: six defects in the Python implementation

This appendix records the problems found while porting and corrected in the R
version. There are three reasons to write them down:

1. if you compare this package's results against the Python implementation
   they will not line up, and you need to know why;
2. an analysis already published using the Python implementation may need
   re-running;
3. these are **this package's own judgements** — each comes with its source
   location and a reproducible example, so you can check rather than take my
   word for it.

Version checked: PoliUniLu `cora`, GitHub main, commit `120bebf` (dated
2026-02-20, `pyproject.toml` version 1.0.1). Line numbers refer to that
commit.

### A.1 The common cause: treating observed values as "0 to k−1"

Three of the six come from one assumption. The Python implementation computes
each condition's **number of levels** like this:

```python
# cora/prime_implicants.py:558-573  _get_levels
dim = [inputs[col].unique() for col in inputs]
...
levels = [len(x) for x in dim_corrected]
```

`levels` is **the count of distinct values**. A condition `B` coded `{1, 2}`
has `levels = 2`.

Nothing is wrong so far. The problem is what happens next, when `levels` is
used as though the domain were `0` to `levels−1`.

### A.2 Defect ①: the domain of a free literal is wrong (ON-OFF)

```python
# cora/multiply.py:45-49
def _transform_to_raw_implicant(impl, levels):
    res = [frozenset(range(i)) for i in levels]      # <- this line
    for x in impl:
        res[x._ident] = frozenset([x._val])
    return tuple(res)
```

A prime implicant has to fill in **every possible value** for the conditions
it does not mention (its free literals). What is filled in here is
`range(levels)`.

For a condition `B` actually taking `{1, 2}` with `levels = 2`, the fill-in
is `{0, 1}`:

- it contains a value **never observed** (0)
- it omits a value **that exists** (2)

Every case with `B = 2` therefore fails to match the implicant and is
excluded from its coverage.

**Reproduced on the Python implementation's own README data** (`B` coded
`{1,2}`):

```python
import pandas as pd, cora
df = pd.DataFrame([[1,2,0,1,1],
                   [1,1,1,0,1],
                   [0,2,1,0,0],
                   [0,2,2,0,1]], columns=["A","B","C","D","OUT"])
for alg in ["ON-DC", "ON-OFF"]:
    c = cora.OptimizationContext(data=df, output_labels=["OUT"],
                                 algorithm=alg, inc_score1=0.5)
    for p in c.get_prime_implicants():
        print(alg, p, p.coverage_score(), p.inclusion_score())
```

The actual output:

| Prime implicant | ON-DC Cov. | ON-DC Inc. | ON-OFF Cov. | ON-OFF Inc. |
|---|---|---|---|---|
| `A{1}` | 0.667 | 1 | **0.333** | 1 |
| `B{1}` | 0.333 | 1 | 0.333 | 1 |
| `C{0}` | 0.333 | 1 | **0.000** | **NaN** |
| `#C{2}` | 0.333 | 1 | **0.000** | **NaN** |
| `D{1}` | 0.333 | 1 | **0.000** | **NaN** |

Both algorithms find **the same five prime implicants and the same chart**.
The difference appears purely in the case-level scores.

**Why the ON-DC column is the right one.** `A{1}` means "A equals 1", and the
expression **says nothing about B**. The rows with A=1 are rows 0 and 1, and
both have OUT=1; there are three rows with OUT=1 (0, 1 and 3). So `A{1}` has
a coverage score of 2/3 = 0.667. ON-OFF returns 0.333 because row 0 has B=2
and B=2 is judged to be outside B's domain — **an expression that places no
constraint on B should not exclude a row because of B's value there**. This
is not a matter of preference; it is a matter of definition.

`C{2}` is starker still: only row 3 has C=2, that row has OUT=1, and the
coverage score should be 1/3. ON-OFF returns 0, which amounts to declaring
that C equalling 2 never happens in the data — when `C{2}` as a prime
implicant was derived from that very row.

The reason ON-DC escapes this is that it builds its configuration table from
`itertools.product(*dim_corrected)` where `dim_corrected` holds
`pd.unique(col.values)` — **the values actually observed**. Nothing in
`_preprocess_data` recodes the conditions, and `_data_validation` checks only
for integers, 0/1 outcomes and constants, so nothing prevents the mismatch.

### A.3 Defect ②: vacuous truth when nothing is covered (ON-OFF)

```python
# cora/prime_implicants.py:738-754
def _output_coverage_of_pi(self, raw_implicant):
    ...
    for ind, out in enumerate(outputs):
        if all( data[out][ data.apply(lambda row: all(...), axis=1) ] ):
            res.add(ind + 1)
    return res
```

This function decides which outcomes a prime implicant corresponds to: for
each outcome column, it checks whether the cases it covers are **all**
positive.

Python's `all()` returns `True` for an **empty** sequence (vacuous truth).
Mathematically that is correct — "every element satisfies P" does hold when
there are no elements — but the meaning here is a disaster:

> Defect ① empties the coverage set → `all([])` is `True` → the prime
> implicant is assigned **every** outcome.

An implicant covering no case at all is recorded as explaining all of them.

**The function has exactly one call site**, `prime_implicants.py:791`, inside
`_get_prime_implicants_on_off`, so defect ② affects ON-OFF only. (Check with
`grep -rn "_output_coverage_of_pi" cora/` across the whole package: the
definition at 738 and the call at 791, nothing else.)

**What this package does**: with defect ① fixed, coverage sets do not empty
for no reason and the trap is never sprung. The R version **keeps the vacuous
truth faithfully** (`output_coverage_of_pi()` in `R/onoff.R`), because on
correctly coded data it is right, and changing it would create a difference
where there need not be one.

### A.4 Defect ③: under ON-OFF with several outcomes, the inclusion score reads the wrong column

The implicant class documents the field this way
(`prime_implicants.py:2043-2045`):

```
output_labels : array of strings
                The array contains the output labels corresponding to the
                implicant.
```

"The output labels **corresponding to the implicant**." But the two paths
pass different things:

```python
# ON-DC path, prime_implicants.py:684-685
output_labels=[self.output_labels[i - 1] for i in list(x for x in x[2])]
#              ^ only the outcomes this implicant corresponds to

# ON-OFF path, prime_implicants.py:816
self.output_labels,
#              ^ every outcome column
```

And `inclusion_score()` (from `prime_implicants.py:2115`) uses that field
directly:

```python
if len(self.outputs) == 1:
    tmp_positive_data = tmp_data[data[self.output_labels[0]] == 1]
    #                                  ^ takes the first
else:
    tmp_positive_data = tmp_data[ data.apply(
        lambda row: all(row[output] == 1 for output in self.output_labels), axis=1) ]
    #                                              ^ requires every outcome to be 1
```

So on the ON-OFF path `self.output_labels[0]` is **the data's first outcome
column**, which need not be the one this implicant corresponds to.

Side by side on the same implicant:

```
ON-DC   C1{0}  outputs=[2]  output_labels=['O2']        inc=1.0
ON-OFF  C1{0}  outputs=[2]  output_labels=['O1','O2']   inc=0.0
```

**This is not "two reasonable definitions".** The same object's `outputs`
field says it corresponds to the second outcome while its `output_labels`
field lists them all — **two fields contradicting each other inside one
object**, with the class documentation calling both "corresponding to the
implicant". What conflicts is the implementation and its own specification,
not two schools of thought.

**What this package does**: always the implicant's own outcome columns. So
here, one prime implicant scores the same under ON-DC and ON-OFF.

### A.5 Defect ④: case notation fails when the coding does not start at zero (both algorithms)

```python
# cora/prime_implicants.py:274-285
def _set_to_str(s, levels, label, is_multi_level):
    if len(s) == levels:
        return ""
    if not is_multi_level:
        if 0 in s:
            return label.lower()        # lower case = value 0
        else:
            return label.upper()        # upper case = value 1
    ...

def _minterm_to_str(minterm, levels, labels, tag, multi_output):
    is_multi_level = any(x > 2 for x in levels)
```

The case is decided by **whether 0 is in the value set**. With `B` coded
`{1, 2}`, `levels = 2` (two distinct values), and if the other conditions are
binary too then `is_multi_level` is `False`, so:

| Literal | Value set | Contains 0? | Printed as |
|---|---|---|---|
| `B = 1` | `{1}` | no | `B` |
| `B = 2` | `{2}` | no | `B` — identical |

**Two different literals print as the same string**, and a reader cannot tell
them apart. This is purely a display problem and does not affect the
computation, but it will make you read the result wrong — and both ON-DC and
ON-OFF print this way (`_minterm_to_str` is called from both paths: lines
678, 715, 728 under ON-DC and 810, 867, 898 under ON-OFF).

**What this package does**: always `X{v}`. `#a + B` here is
`#A{0} + B{1}`. Every literal carries its own value and there is no ambiguity
however the condition is coded. (`cora_logigram()` still accepts case
notation as **input**, so an expression written by hand or lifted from the
Python implementation can be drawn directly.)

### A.6 Defect ⑤: the data-mining tautology check can never fire

```python
# cora/data_mining_cora.py:13-21
if (
    out_len == 1
    and len(irrendudant_systems) == 1
    and (str(irrendudant_systems[0].system[0].implicant) == "1")
):
    self.nr_irr_systems = 0
    self.inc_score = 0
    ...
```

The intent is clear and correct: **a combination whose only solution is the
tautology `1` should score no solutions and zero**. Every observed
configuration is positive there; it explains nothing and should not rank
highly.

But a tautological solution **is necessarily an essential prime implicant**
(it holds every positive case on its own), so the `implicant` string is
`"#1"` and not `"1"` — `prime_implicants.py:2229` prepends the marker — and
the comparison is always `False`.

**Measured**:

```python
df = pd.DataFrame([[1,1,0,1],[0,0,1,1],[1,0,1,1],[0,1,0,1]],
                  columns=["A","B","C","OUT"])
cora.data_mining(df, ["OUT"], 1)
```

```
  Combination  Nr_of_systems  Inc_score  Cov_score  Score
0         [A]              1        1.0        1.0    1.0
1         [B]              1        1.0        1.0    1.0
2         [C]              1        1.0        1.0    1.0
```

OUT is 1 throughout, the three conditions explain nothing, and all three
score a perfect 1.0 — **the highest score obtainable**.

This package on the same data:

```r
df <- data.frame(A = c(1,0,1,0), B = c(1,0,0,1), C = c(0,1,1,0), OUT = c(1,1,1,1))
cora_data_mining(df, "OUT", len_of_tuple = 1)
#>   Combination Nr_of_systems Inc_score Cov_score Score
#> 1           A             0         0         0     0
#> 2           B             0         0         0     0
#> 3           C             0         0         0     0
```

This is also what `automatic = TRUE` depends on: it widens the search until a
non-empty solution appears, and if a tautology counts as a perfect solution
the search stops at the first step.

### A.6b Defect ⑥: `max_depth` is not wired to the public method

```python
# cora/prime_implicants.py:1025
def get_irredundant_sums(self, max_depth=None):
    """
    max_depth : int
               A positive integer denoting max number of prime implicants
               in the solution.
    ...
    with respect to the max_depth condition.
    """
```

The documentation is explicit: an upper bound on the number of prime
implicants in a solution. Measured, though:

```python
for md in (None, 1, 2, 0):
    c = cora.OptimizationContext(data=df, output_labels=["OUT"])
    print(md, len(c.get_irredundant_sums(max_depth=md)))
# None -> 2 solutions, 1 -> 2, 2 -> 2, 0 -> 2
```

Even `max_depth = 0` returns every solution.

**This is not a missing implementation — the implementation exists and is
correct.** The pure-Python solver in `cora/petric.py` implements the bound in
full:

```python
# cora/petric.py:21-42
def _find_irredundant_sums(implicants_with_coverage, coverage, max_depth=None):
    if max_depth is None:
        max_depth = len(implicants_with_coverage)
    ...

def _find_irrendundant_sums_internal(..., max_depth):
    # If we reached maximal depth / maximal length of the sum, do not continue.
    if len(partial_solution) > max_depth:
        return
```

**That is exactly "prune during the search"** — the same design this package
uses. It is exported from `cora/__init__.py` and the package's own
`tests/test_petric.py` exercises it.

The break is in the wiring. `get_irredundant_sums` calls the **native (C++)**
solver:

```python
# cora/prime_implicants.py:1067
result = _find_irredundant_sums_native(
    ([(i, i.coverage) for i in prime_implicants]), self.cares
)

# cora/petric.py:6 -- two parameters, with no place for a bound
def _find_irredundant_sums_native(implicants_with_coverage, coverage):
```

The native solver's signature has **no** `max_depth`, and the call site does
not pass one. When the package moved to the C++ solver for speed, the
parameter was left **disconnected** from the public method — the
documentation stayed, the behaviour went.

> **This one is unlike the other five.** Those are errors of logic or
> meaning; this is a parameter dropped during an optimisation. The original
> authors knew what the bound should do and implemented it correctly — that
> implementation is simply unreachable from the documented method. This
> package's `max_depth` amounts to reconnecting that route (§7.3.1).

### A.7 After the fix

Once the data is recoded to start at zero (`cora_recode(df, "B")`), this
package's two algorithms return **identical** results:

```r
df <- data.frame(A = c(1,1,0,0), B = c(2,1,2,2), C = c(0,1,1,2),
                 D = c(1,0,0,0), OUT = c(1,1,0,1))
df <- cora_recode(df, "B")
for (alg in c("ON-DC", "ON-OFF")) {
  print(cora_pi_details(cora_context(df, "OUT", algorithm = alg,
                                     inc_score1 = 0.5)))
}
```

The prime implicant sets, `Cov.r`, `Inc.` and the unique coverage of each
solution all agree (only the row order differs). Against the table in A.2,
every 0.333 / 0.000 / NaN in the ON-OFF column is gone.

> **Recoding shifts the labels**: once `B` goes from `{1,2}` to `{0,1}`, the
> old `B{2}` is `B{1}`. The structure is identical; only the numeric labels
> follow the coding. Remember to convert when comparing against literature
> that used the Python implementation.

### A.8 Where responsibility lies

This package and the Python implementation **share one theory** (CORA/CCM).
Therefore:

- **Where the two agree** and something is wrong, that is a problem of the
  method itself, belonging to the original authors' theory and
  implementation.
- **Where this package differs** from the Python implementation and something
  is wrong, the responsibility is this package's, not the original authors'.

All six items above are differences. Each carries its source location and a
reproducible example precisely so that you can judge for yourself whether the
change was right, rather than taking my word for it.

---

## Appendix B: how QCA, QCApro and cna do it

These three R packages address neighbouring problems (QCA and CNA) and each
has a settled approach to coding multi-value conditions and printing
literals. This package's two design decisions — **always `X{v}`** and
**refuse coding that does not start at zero** — were made after looking at
them. Source locations below; versions are in the headings.

### B.1 QCA (3.25.5, Duşa) with admisc

**Internally: 0 is a sentinel, the real value is stored +1.**

```r
# admisc/R/writePIs.R:29-38
if (mv) {
    chars <- matrix(paste(chars,
                          ifelse(curly, "{", "["),
                          impmat - 1,                 # <- subtract 1 to print
                          ifelse(curly, "}", "]"), sep = ""), ...)
}
```

In the implicant matrix `0` means "this condition does not appear in this
term"; the real value is always stored one higher and subtracted back when
printed.

**Notation**: `A[1]` for multi-value (square brackets), or `A{1}` with
`curly = TRUE`. Binary negation is a tilde:

```r
# admisc/R/writePIs.R:52
chars <- ifelse(impmat == 1L, paste0("~", chars), chars)
```

**Note that QCA no longer writes negation as case; it uses a tilde.** Worth
remembering — the `a` in the literature is the older convention.

**Switching to multi-value notation is automatic**:

```r
# admisc/R/writePIs.R:8-10
if (any(impmat > 2)) {
    mv <- TRUE
}
```

`impmat > 2` means "some stored value is 3 or more", and since storage adds
one, that is **a real value of 2 or more switches to multi-value notation**.

**The level count assumes a zero start**:

```r
# admisc/R/getLevels.R
noflevels[pN] <- apply(data[, pN, drop = FALSE], 2,
                       function(x) max(as.numeric(x))) + 1
```

`max + 1`. A condition coded `{1, 2}` gets `noflevels = 3`, and the truth
table gains a configuration for "value 0" — something the data does not
contain, but it is treated as an **unobserved configuration** (a remainder)
and raises no error.

> So QCA **also assumes zero-based coding**; its failure mode is just
> gentler — one phantom configuration rather than real cases excluded. QCA's
> manual asks the user to code multi-value conditions `0, 1, 2, ...`.

### B.2 QCApro (1.1-2, Thiem)

Another package by the same author, who is also one of the authors of the
CORA paper.

```r
# QCApro/R/writePrimeimp.R:12-22
for (i in seq(ncol(idx))) {
    if (uplow) {
        conditions <- c(tolower(colnames(idx)[i]), toupper(colnames(idx)[i]))
    } else if (use.tilde) {
        conditions <- c(paste("~", toupper(colnames(idx)[i]), sep=""), ...)
    } else {
        conditions <- paste(colnames(idx)[i], "{", seq(max(idx[, i])) - 1, "}", sep="")
    }                                      # ^ X{v}
}
```

Three notations: case, tilde, and `X{v}`. The important part is **when each
is used**:

```r
# QCApro/R/eQMC.R:253-256
if (any(recdata[, seq(ncol(recdata) - 1)] > 1)) {
    uplow <- FALSE
    use.tilde <- FALSE
}
```

**As soon as any condition takes a value above 1, case and tilde are forced
off and the notation falls to `X{v}`** — overriding even a `use.tilde = TRUE`
the user asked for explicitly.

This is the most direct precedent for this package's choice: **the CORA
author's own R package switches unconditionally to `X{v}` the moment the data
is multi-value.** This package only carries it further — binary data is
printed the same way, so there are not two notations to keep track of.

### B.3 cna (4.0.3, Ambühl / Baumgartner)

cna's approach is the cleanest and the most instructive: **it does not assume
values start at zero at all.**

```r
# cna/R/cna_aux.r:60-67
} else if (type == "mv") {
    uniqueValues <- lapply(ct, function(x) sort(unique.default(x)))
    resp_nms <- mapply(paste, names(ct), uniqueValues,
                       MoreArgs = list(sep = "="), SIMPLIFY = FALSE)
    resp_nms <- unlist(resp_nms, use.names = FALSE)
    valueId <- mapply(match, ct, uniqueValues, SIMPLIFY = TRUE, USE.NAMES = TRUE)
    ...
}
```

Two things matter here:

1. `uniqueValues` holds **the values actually observed** (`sort(unique(x))`),
   not `0:(k-1)`.
2. `valueId` uses `match()` to get **the position in that observed sequence**,
   not the value itself. The internals work on positions; the display uses
   the real values.

**Notation**: `A=1`, with the real value written straight into the literal's
name (which is also the column name of the internal matrix).

A condition coded `{1, 2}` is therefore a non-issue in cna: it prints `B=1`
and `B=2`, works internally with positions 1 and 2, and nowhere needs a zero
to exist.

### B.4 The four side by side, and this package's choices

| | Multi-value notation | Binary negation | Internal domain | When coding does not start at zero |
|---|---|---|---|---|
| **QCA** | `A[1]` (`A{1}` optional) | `~A` | `0` sentinel, value +1; levels = `max + 1` | a phantom configuration, no error |
| **QCApro** | `A{1}` | case or `~A` (forced off when multi-value) | values `0..max` | — |
| **cna** | `A=1` | case | **observed values**, positional index | wholly unaffected |
| **CORA (Python)** | `A{1}` | case | assumes `0..levels-1` | **quietly wrong** (Appendix A) |
| **CORAtool (this package)** | `A{1}`, **always** | `A{0}`, no case | **observed values** (following cna) | **error**, naming `cora_recode()` |

The reasoning behind the three decisions:

1. **Always `X{v}`** — consistent with QCApro's multi-value default and with
   the Python CORA's multi-value output. The only extension is printing
   binary data the same way, because the basis for the case (whether 0 is in
   the value set) fails when the coding does not start at zero (A.5).
2. **Observed values internally** — following cna. This is what fixes defect
   ① (A.2) and keeps the trap in A.3 from ever being sprung.
3. **Refusing coding that does not start at zero** — **stricter than all
   three**. QCA does not error (it treats the gap as an unobserved
   configuration); cna has no need to (it never assumes a zero). This package
   errors even though the underlying cause is fixed, because:
   - CORA's **truth table has `prod(levels)` rows**, and non-zero coding
     makes what that table means hard to explain;
   - a silent label shift (`B{2}` becoming `B{1}`) would have readers
     misreading results against the literature;
   - refusing costs one line of `cora_recode()`; getting it wrong costs a
     paper.

---

## Appendix C: the bundled data sets carry no variable definitions

This package ships four data sets: `swiss_minaret`, `gross_carvin`,
`mccluskey` and `bergschlosser`. They are taken unchanged from the
`examples/` directory of the Python CORA package.

**One thing has to be said plainly: the upstream data files contain column
abbreviations and no variable definitions at all.**

- `gross_carvin`'s `LENG`, `UPSI`, `RISK`, `FRFL`, `MIMA`, `DOSI`, `PRIC` —
  the Python package supplies no account of what each abbreviation stands
  for or what the values 0/1/2 mean.
- The same for `swiss_minaret`'s `L`, `T`, `S`, `A`.
- The same for `bergschlosser`'s columns.

So this package's documentation describes these data sets **structurally**
only (how many conditions, how many outcomes, how many rows, what range the
values take) and offers no substantive interpretation.

**What that means for you:**

- These data sets are good for **learning the syntax, checking output and
  testing performance**.
- They are **not suitable for substantive inference or for quoting
  conclusions from** — `LENG{2}` means nothing without a definition.
- To analyse this data substantively you need the codebook from the original
  literature (`gross_carvin` points to Gross & Carvin's work on tort
  liability, `bergschlosser` to Berg-Schlosser's research).

Your own data will not have this problem: you coded the columns and you know
what each value means — which is precisely what **has to go into the write-up**
(§4.4, step five).

---

## Appendix D: authorship, citation and responsibility

### D.1 Why the original authors are `cph` and not `aut`

`Authors@R` in `DESCRIPTION` reads:

```r
person("Young", "Chan", role = c("aut", "cre", "cph"),
       comment = "Author of the R implementation"),
person("Zuzana", "Sebechlebská", role = "cph",
       comment = "Copyright holder of the original Python implementation"),
person("Lusine", "Mkrtchyan", role = "cph", ...),
person("Alrik", "Thiem", role = "cph", ...)
```

The original authors are listed as `cph` (copyright holder) and **not** as
`aut` (author). The reasoning:

- This package is a GPL-3 derivative work, and the original authors **hold
  copyright** in the parts derived from the Python implementation. That has
  to be stated, and `cph` is the role that states it.
- But `aut` in CRAN's conventions means **responsibility for what the package
  contains**. This package departs from the Python implementation in seven
  deliberate places (§8, Appendix A). The original authors took no part in
  those judgements and had no chance to review them. Listing them as `aut`
  would have them endorsing changes they may disagree with and do not know
  about.
- There is a practical layer too: CRAN review sometimes asks what an `aut`
  contributed. "They wrote the original in another language and I changed
  seven things" is not what `aut` means.

The Description field in `DESCRIPTION` therefore ends:

> It is an independent implementation and is not endorsed by the authors of
> the original packages.

`inst/NOTICE` records the full derivation and licensing.

### D.2 Citation order

```r
citation("CORAtool")
```

lists three entries, in this order:

1. **This package** (and, in due course, the article about it)
2. **The CORA method paper**: Thiem, Mkrtchyan & Sebechlebská (2022), *BMC
   Medical Research Methodology*, 22(1), 333. doi:10.1186/s12874-022-01800-9
3. **The Python packages paper**: Sebechlebská, Mkrtchyan & Thiem (2023),
   *JOSS*, 8(85), 5019. doi:10.21105/joss.05019

**An analysis using CORA must cite the second**, whatever software produced
the results, because that is where the method comes from. Cite the third when
you actually used the Python implementation (cross-checking with
`cora_compare_python()`, for instance).

### D.3 Responsibility in one sentence

> Where this package and the Python implementation **agree** and something is
> wrong, that is a problem of the shared theory and method.
> Where they **differ** and something is wrong, the responsibility is this
> package's, not the original authors'.

The README opens with this and Appendix A.8 repeats it. It is not a
courtesy: each of the six items in Appendix A carries its source location and
a reproducible example precisely so the sentence can be checked.
