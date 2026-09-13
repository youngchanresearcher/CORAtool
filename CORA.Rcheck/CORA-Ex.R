pkgname <- "CORA"
source(file.path(R.home("share"), "R", "examples-header.R"))
options(warn = 1)
base::assign(".ExTimings", "CORA-Ex.timings", pos = 'CheckExEnv')
base::cat("name\tuser\tsystem\telapsed\n", file=base::get(".ExTimings", pos = 'CheckExEnv'))
base::assign(".format_ptime",
function(x) {
  if(!is.na(x[4L])) x[1L] <- x[1L] + x[4L]
  if(!is.na(x[5L])) x[2L] <- x[2L] + x[5L]
  options(OutDec = '.')
  format(x[1L:3L], digits = 7L)
},
pos = 'CheckExEnv')

### * </HEADER>
library('CORA')

base::assign(".oldSearch", base::search(), pos = 'CheckExEnv')
base::assign(".old_wd", base::getwd(), pos = 'CheckExEnv')
cleanEx()
nameEx("bergschlosser")
### * bergschlosser

flush(stderr()); flush(stdout())

base::assign(".ptime", proc.time(), pos = "CheckExEnv")
### Name: bergschlosser
### Title: Berg-Schlosser and De Meur's praetorianism data
### Aliases: bergschlosser
### Keywords: datasets

### ** Examples

ctx <- cora_context(bergschlosser, "PRAET",
                    input_labels = c("PS", "RQ", "LRC", "AUTH"),
                    inc_score1 = 0.6, case_col = "Case")
cora_irredundant_sums(ctx)



base::assign(".dptime", (proc.time() - get(".ptime", pos = "CheckExEnv")), pos = "CheckExEnv")
base::cat("bergschlosser", base::get(".format_ptime", pos = 'CheckExEnv')(get(".dptime", pos = "CheckExEnv")), "\n", file=base::get(".ExTimings", pos = 'CheckExEnv'), append=TRUE, sep="\t")
cleanEx()
nameEx("cora_compare_python")
### * cora_compare_python

flush(stderr()); flush(stdout())

base::assign(".ptime", proc.time(), pos = "CheckExEnv")
### Name: cora_compare_python
### Title: Cross-check a result against the Python implementation
### Aliases: cora_compare_python

### ** Examples

df <- data.frame(A = c(1, 0, 1, 0), B = c(1, 0, 0, 1),
                 C = c(0, 1, 1, 0), OUT = c(1, 1, 0, 1))
if (cora_python_available()) {
  cora_compare_python(cora_context(df, "OUT"))
}



base::assign(".dptime", (proc.time() - get(".ptime", pos = "CheckExEnv")), pos = "CheckExEnv")
base::cat("cora_compare_python", base::get(".format_ptime", pos = 'CheckExEnv')(get(".dptime", pos = "CheckExEnv")), "\n", file=base::get(".ExTimings", pos = 'CheckExEnv'), append=TRUE, sep="\t")
cleanEx()
nameEx("cora_context")
### * cora_context

flush(stderr()); flush(stdout())

base::assign(".ptime", proc.time(), pos = "CheckExEnv")
### Name: cora_context
### Title: Create an optimisation context
### Aliases: cora_context

### ** Examples

df <- data.frame(A = c(1, 0, 1, 0), B = c(1, 0, 0, 1),
                 C = c(0, 1, 1, 0), OUT = c(1, 1, 0, 1))
ctx <- cora_context(df, output_labels = "OUT")
cora_prime_implicants(ctx)




base::assign(".dptime", (proc.time() - get(".ptime", pos = "CheckExEnv")), pos = "CheckExEnv")
base::cat("cora_context", base::get(".format_ptime", pos = 'CheckExEnv')(get(".dptime", pos = "CheckExEnv")), "\n", file=base::get(".ExTimings", pos = 'CheckExEnv'), append=TRUE, sep="\t")
cleanEx()
nameEx("cora_coverage_score")
### * cora_coverage_score

flush(stderr()); flush(stdout())

base::assign(".ptime", proc.time(), pos = "CheckExEnv")
### Name: cora_coverage_score
### Title: Sufficiency statistics of a prime implicant
### Aliases: cora_coverage_score cora_inclusion_score

### ** Examples

df <- data.frame(A = c(1, 0, 1, 0), B = c(1, 0, 0, 1),
                 C = c(0, 1, 1, 0), OUT = c(1, 1, 0, 1))
pis <- cora_prime_implicants(cora_context(df, "OUT"))
cora_coverage_score(pis[[1]])
cora_inclusion_score(pis[[1]])



base::assign(".dptime", (proc.time() - get(".ptime", pos = "CheckExEnv")), pos = "CheckExEnv")
base::cat("cora_coverage_score", base::get(".format_ptime", pos = 'CheckExEnv')(get(".dptime", pos = "CheckExEnv")), "\n", file=base::get(".ExTimings", pos = 'CheckExEnv'), append=TRUE, sep="\t")
cleanEx()
nameEx("cora_data_mining")
### * cora_data_mining

flush(stderr()); flush(stdout())

base::assign(".ptime", proc.time(), pos = "CheckExEnv")
### Name: cora_data_mining
### Title: Configurational data mining
### Aliases: cora_data_mining

### ** Examples

data <- data.frame(A = c(1, 1, 1, 0), B = c(0, 1, 0, 1),
                   C = c(1, 1, 0, 0), O = c(0, 1, 0, 1))
cora_data_mining(data, "O", len_of_tuple = 2)



base::assign(".dptime", (proc.time() - get(".ptime", pos = "CheckExEnv")), pos = "CheckExEnv")
base::cat("cora_data_mining", base::get(".format_ptime", pos = 'CheckExEnv')(get(".dptime", pos = "CheckExEnv")), "\n", file=base::get(".ExTimings", pos = 'CheckExEnv'), append=TRUE, sep="\t")
cleanEx()
nameEx("cora_describe")
### * cora_describe

flush(stderr()); flush(stdout())

base::assign(".ptime", proc.time(), pos = "CheckExEnv")
### Name: cora_describe
### Title: Descriptive rendering of a solution
### Aliases: cora_describe

### ** Examples

df <- data.frame(A = c(1, 0, 1, 0), B = c(1, 0, 0, 1),
                 C = c(0, 1, 1, 0), OUT = c(1, 1, 0, 1))
sums <- cora_irredundant_sums(cora_context(df, "OUT"))
cora_describe(sums[[1]])



base::assign(".dptime", (proc.time() - get(".ptime", pos = "CheckExEnv")), pos = "CheckExEnv")
base::cat("cora_describe", base::get(".format_ptime", pos = 'CheckExEnv')(get(".dptime", pos = "CheckExEnv")), "\n", file=base::get(".ExTimings", pos = 'CheckExEnv'), append=TRUE, sep="\t")
cleanEx()
nameEx("cora_dnf")
### * cora_dnf

flush(stderr()); flush(stdout())

base::assign(".ptime", proc.time(), pos = "CheckExEnv")
### Name: cora_dnf
### Title: Disjunctive normal form of a solution
### Aliases: cora_dnf

### ** Examples

df <- data.frame(A = c(1, 0, 1, 0), B = c(1, 0, 0, 1),
                 C = c(0, 1, 1, 0), OUT = c(1, 1, 0, 1))
cora_dnf(cora_irredundant_sums(cora_context(df, "OUT"))[[1]])



base::assign(".dptime", (proc.time() - get(".ptime", pos = "CheckExEnv")), pos = "CheckExEnv")
base::cat("cora_dnf", base::get(".format_ptime", pos = 'CheckExEnv')(get(".dptime", pos = "CheckExEnv")), "\n", file=base::get(".ExTimings", pos = 'CheckExEnv'), append=TRUE, sep="\t")
cleanEx()
nameEx("cora_irredundant_sums")
### * cora_irredundant_sums

flush(stderr()); flush(stdout())

base::assign(".ptime", proc.time(), pos = "CheckExEnv")
### Name: cora_irredundant_sums
### Title: Irredundant sums of a single-outcome analysis
### Aliases: cora_irredundant_sums

### ** Examples

df <- data.frame(A = c(1, 0, 1, 0), B = c(1, 0, 0, 1),
                 C = c(0, 1, 1, 0), OUT = c(1, 1, 0, 1))
cora_irredundant_sums(cora_context(df, "OUT"))

## Only the solutions built from at most one prime implicant.
cora_irredundant_sums(cora_context(df, "OUT"), max_depth = 1)



base::assign(".dptime", (proc.time() - get(".ptime", pos = "CheckExEnv")), pos = "CheckExEnv")
base::cat("cora_irredundant_sums", base::get(".format_ptime", pos = 'CheckExEnv')(get(".dptime", pos = "CheckExEnv")), "\n", file=base::get(".ExTimings", pos = 'CheckExEnv'), append=TRUE, sep="\t")
cleanEx()
nameEx("cora_irredundant_systems")
### * cora_irredundant_systems

flush(stderr()); flush(stdout())

base::assign(".ptime", proc.time(), pos = "CheckExEnv")
### Name: cora_irredundant_systems
### Title: Irredundant systems of a multi-outcome analysis
### Aliases: cora_irredundant_systems

### ** Examples

df <- data.frame(A = c(1, 1, 0, 0), B = c(2, 1, 2, 2), C = c(0, 1, 1, 2),
                 D = c(1, 0, 0, 0), OUT1 = c(1, 2, 0, 1),
                 OUT2 = c(2, 0, 1, 1), OUT3 = c(1, 0, 2, 1))
## B is coded 1 and 2 here, which CORA does not accept.
df <- cora_recode(df, "B")
ctx <- cora_context(df, c("OUT1{1,2}", "OUT2{1}", "OUT3{1,0}"),
                    algorithm = "ON-OFF")
cora_irredundant_systems(ctx)



base::assign(".dptime", (proc.time() - get(".ptime", pos = "CheckExEnv")), pos = "CheckExEnv")
base::cat("cora_irredundant_systems", base::get(".format_ptime", pos = 'CheckExEnv')(get(".dptime", pos = "CheckExEnv")), "\n", file=base::get(".ExTimings", pos = 'CheckExEnv'), append=TRUE, sep="\t")
cleanEx()
nameEx("cora_logigram")
### * cora_logigram

flush(stderr()); flush(stdout())

base::assign(".ptime", proc.time(), pos = "CheckExEnv")
### Name: cora_logigram
### Title: Draw a two-level logic diagram
### Aliases: cora_logigram cora_logigram.default cora_logigram.cora_system
###   cora_logigram.cora_system_multi cora_logigram.cora_context

### ** Examples

cora_logigram("A*B+c*A+b<=>F")
cora_logigram("A{1}*B{2}+C{0}<=>F")

df <- data.frame(A = c(1, 0, 1, 0), B = c(1, 0, 0, 1),
                 C = c(0, 1, 1, 0), OUT = c(1, 1, 0, 1))
sol <- cora_irredundant_sums(cora_context(df, "OUT"))[[1]]

## The solution and its scores are written above the diagram.
cora_logigram(sol)

## Each conjunction next to its own gate, and no header.
cora_logigram(sol, title = NA, subtitle = NA, show_terms = TRUE)



base::assign(".dptime", (proc.time() - get(".ptime", pos = "CheckExEnv")), pos = "CheckExEnv")
base::cat("cora_logigram", base::get(".format_ptime", pos = 'CheckExEnv')(get(".dptime", pos = "CheckExEnv")), "\n", file=base::get(".ExTimings", pos = 'CheckExEnv'), append=TRUE, sep="\t")
cleanEx()
nameEx("cora_petrick")
### * cora_petrick

flush(stderr()); flush(stdout())

base::assign(".ptime", proc.time(), pos = "CheckExEnv")
### Name: cora_petrick
### Title: Solve a prime implicant chart with Petrick's method
### Aliases: cora_petrick

### ** Examples

cora_petrick(list(c(1, 2), c(2, 3), c(3, 4)))

## Only the sums built from at most two prime implicants.
cora_petrick(list(c(1, 2), c(2, 3), c(3, 4)), max_depth = 2)



base::assign(".dptime", (proc.time() - get(".ptime", pos = "CheckExEnv")), pos = "CheckExEnv")
base::cat("cora_petrick", base::get(".format_ptime", pos = 'CheckExEnv')(get(".dptime", pos = "CheckExEnv")), "\n", file=base::get(".ExTimings", pos = 'CheckExEnv'), append=TRUE, sep="\t")
cleanEx()
nameEx("cora_pi_chart")
### * cora_pi_chart

flush(stderr()); flush(stdout())

base::assign(".ptime", proc.time(), pos = "CheckExEnv")
### Name: cora_pi_chart
### Title: Prime implicant chart
### Aliases: cora_pi_chart

### ** Examples

df <- data.frame(A = c(1, 0, 1, 0), B = c(1, 0, 0, 1),
                 C = c(0, 1, 1, 0), OUT = c(1, 1, 0, 1))
cora_pi_chart(cora_context(df, "OUT"))



base::assign(".dptime", (proc.time() - get(".ptime", pos = "CheckExEnv")), pos = "CheckExEnv")
base::cat("cora_pi_chart", base::get(".format_ptime", pos = 'CheckExEnv')(get(".dptime", pos = "CheckExEnv")), "\n", file=base::get(".ExTimings", pos = 'CheckExEnv'), append=TRUE, sep="\t")
cleanEx()
nameEx("cora_pi_details")
### * cora_pi_details

flush(stderr()); flush(stdout())

base::assign(".ptime", proc.time(), pos = "CheckExEnv")
### Name: cora_pi_details
### Title: Statistical overview of the prime implicants
### Aliases: cora_pi_details

### ** Examples

df <- data.frame(A = c(1, 0, 1, 0), B = c(1, 0, 0, 1),
                 C = c(0, 1, 1, 0), OUT = c(1, 1, 0, 1))
cora_pi_details(cora_context(df, "OUT"))



base::assign(".dptime", (proc.time() - get(".ptime", pos = "CheckExEnv")), pos = "CheckExEnv")
base::cat("cora_pi_details", base::get(".format_ptime", pos = 'CheckExEnv')(get(".dptime", pos = "CheckExEnv")), "\n", file=base::get(".ExTimings", pos = 'CheckExEnv'), append=TRUE, sep="\t")
cleanEx()
nameEx("cora_prime_implicants")
### * cora_prime_implicants

flush(stderr()); flush(stdout())

base::assign(".ptime", proc.time(), pos = "CheckExEnv")
### Name: cora_prime_implicants
### Title: Prime implicants of an optimisation context
### Aliases: cora_prime_implicants

### ** Examples

df <- data.frame(A = c(1, 0, 1, 0), B = c(1, 0, 0, 1),
                 C = c(0, 1, 1, 0), OUT = c(1, 1, 0, 1))
cora_prime_implicants(cora_context(df, "OUT"))



base::assign(".dptime", (proc.time() - get(".ptime", pos = "CheckExEnv")), pos = "CheckExEnv")
base::cat("cora_prime_implicants", base::get(".format_ptime", pos = 'CheckExEnv')(get(".dptime", pos = "CheckExEnv")), "\n", file=base::get(".ExTimings", pos = 'CheckExEnv'), append=TRUE, sep="\t")
cleanEx()
nameEx("cora_python_available")
### * cora_python_available

flush(stderr()); flush(stdout())

base::assign(".ptime", proc.time(), pos = "CheckExEnv")
### Name: cora_python_available
### Title: Is the Python CORA package reachable?
### Aliases: cora_python_available

### ** Examples

cora_python_available()



base::assign(".dptime", (proc.time() - get(".ptime", pos = "CheckExEnv")), pos = "CheckExEnv")
base::cat("cora_python_available", base::get(".format_ptime", pos = 'CheckExEnv')(get(".dptime", pos = "CheckExEnv")), "\n", file=base::get(".ExTimings", pos = 'CheckExEnv'), append=TRUE, sep="\t")
cleanEx()
nameEx("cora_recode")
### * cora_recode

flush(stderr()); flush(stdout())

base::assign(".ptime", proc.time(), pos = "CheckExEnv")
### Name: cora_recode
### Title: Recode conditions onto 0, 1, 2, ...
### Aliases: cora_recode

### ** Examples

df <- data.frame(A = c(2, 1, 2, 1), B = c(1, 2, 1, 2), OUT = c(1, 0, 1, 1))
cora_recode(df, c("A", "B"))

## A rating scale collected as 1-5 becomes 0-4.
cora_recode(data.frame(score = c(3, 1, 5, 1)), "score")

## Left to itself it recodes exactly the columns that need it.
cora_recode(df)



base::assign(".dptime", (proc.time() - get(".ptime", pos = "CheckExEnv")), pos = "CheckExEnv")
base::cat("cora_recode", base::get(".format_ptime", pos = 'CheckExEnv')(get(".dptime", pos = "CheckExEnv")), "\n", file=base::get(".ExTimings", pos = 'CheckExEnv'), append=TRUE, sep="\t")
cleanEx()
nameEx("cora_solutions")
### * cora_solutions

flush(stderr()); flush(stdout())

base::assign(".ptime", proc.time(), pos = "CheckExEnv")
### Name: cora_solutions
### Title: Solution summary table
### Aliases: cora_solutions

### ** Examples

df <- data.frame(A = c(1, 0, 1, 0), B = c(1, 0, 0, 1),
                 C = c(0, 1, 1, 0), OUT = c(1, 1, 0, 1))
cora_solutions(cora_context(df, "OUT"))



base::assign(".dptime", (proc.time() - get(".ptime", pos = "CheckExEnv")), pos = "CheckExEnv")
base::cat("cora_solutions", base::get(".format_ptime", pos = 'CheckExEnv')(get(".dptime", pos = "CheckExEnv")), "\n", file=base::get(".ExTimings", pos = 'CheckExEnv'), append=TRUE, sep="\t")
cleanEx()
nameEx("cora_system_details")
### * cora_system_details

flush(stderr()); flush(stdout())

base::assign(".ptime", proc.time(), pos = "CheckExEnv")
### Name: cora_system_details
### Title: Statistical overview of a solution
### Aliases: cora_system_details

### ** Examples

df <- data.frame(A = c(1, 0, 1, 0), B = c(1, 0, 0, 1),
                 C = c(0, 1, 1, 0), OUT = c(1, 1, 0, 1))
cora_system_details(cora_context(df, "OUT"))



base::assign(".dptime", (proc.time() - get(".ptime", pos = "CheckExEnv")), pos = "CheckExEnv")
base::cat("cora_system_details", base::get(".format_ptime", pos = 'CheckExEnv')(get(".dptime", pos = "CheckExEnv")), "\n", file=base::get(".ExTimings", pos = 'CheckExEnv'), append=TRUE, sep="\t")
cleanEx()
nameEx("cora_truth_table")
### * cora_truth_table

flush(stderr()); flush(stdout())

base::assign(".ptime", proc.time(), pos = "CheckExEnv")
### Name: cora_truth_table
### Title: Truth table of an optimisation context
### Aliases: cora_truth_table

### ** Examples

df <- data.frame(A = c(1, 0, 1, 1, 1), B = c(0, 1, 1, 1, 1),
                 C = c(0, 0, 1, 1, 1), O = c(1, 1, 0, 1, 1))
cora_truth_table(cora_context(df, "O", inc_score1 = 0.5))



base::assign(".dptime", (proc.time() - get(".ptime", pos = "CheckExEnv")), pos = "CheckExEnv")
base::cat("cora_truth_table", base::get(".format_ptime", pos = 'CheckExEnv')(get(".dptime", pos = "CheckExEnv")), "\n", file=base::get(".ExTimings", pos = 'CheckExEnv'), append=TRUE, sep="\t")
cleanEx()
nameEx("gross_carvin")
### * gross_carvin

flush(stderr()); flush(stdout())

base::assign(".ptime", proc.time(), pos = "CheckExEnv")
### Name: gross_carvin
### Title: Tort liability of highway authorities
### Aliases: gross_carvin
### Keywords: datasets

### ** Examples

ctx <- cora_context(gross_carvin, "TORT", case_col = "Case")
cora_prime_implicants(ctx)



base::assign(".dptime", (proc.time() - get(".ptime", pos = "CheckExEnv")), pos = "CheckExEnv")
base::cat("gross_carvin", base::get(".format_ptime", pos = 'CheckExEnv')(get(".dptime", pos = "CheckExEnv")), "\n", file=base::get(".ExTimings", pos = 'CheckExEnv'), append=TRUE, sep="\t")
cleanEx()
nameEx("mccluskey")
### * mccluskey

flush(stderr()); flush(stdout())

base::assign(".ptime", proc.time(), pos = "CheckExEnv")
### Name: mccluskey
### Title: McCluskey's two-output switching function
### Aliases: mccluskey
### Keywords: datasets

### ** Examples

cora_data_mining(mccluskey, c("F1", "F2"), len_of_tuple = 2)



base::assign(".dptime", (proc.time() - get(".ptime", pos = "CheckExEnv")), pos = "CheckExEnv")
base::cat("mccluskey", base::get(".format_ptime", pos = 'CheckExEnv')(get(".dptime", pos = "CheckExEnv")), "\n", file=base::get(".ExTimings", pos = 'CheckExEnv'), append=TRUE, sep="\t")
cleanEx()
nameEx("swiss_minaret")
### * swiss_minaret

flush(stderr()); flush(stdout())

base::assign(".ptime", proc.time(), pos = "CheckExEnv")
### Name: swiss_minaret
### Title: Swiss minaret referendum
### Aliases: swiss_minaret
### Keywords: datasets

### ** Examples

ctx <- cora_context(swiss_minaret, c("X", "M"), algorithm = "ON-OFF")
cora_irredundant_systems(ctx)



base::assign(".dptime", (proc.time() - get(".ptime", pos = "CheckExEnv")), pos = "CheckExEnv")
base::cat("swiss_minaret", base::get(".format_ptime", pos = 'CheckExEnv')(get(".dptime", pos = "CheckExEnv")), "\n", file=base::get(".ExTimings", pos = 'CheckExEnv'), append=TRUE, sep="\t")
### * <FOOTER>
###
cleanEx()
options(digits = 7L)
base::cat("Time elapsed: ", proc.time() - base::get("ptime", pos = 'CheckExEnv'),"\n")
grDevices::dev.off()
###
### Local variables: ***
### mode: outline-minor ***
### outline-regexp: "\\(> \\)?### [*]+" ***
### End: ***
quit('no')
