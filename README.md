# Are Congressional Committees Preference Outliers?

A small, reproducible, **pre-registered** test of the classic distributive-vs-informational question (Krehbiel, *Are Committees Composed of Preference Outliers?*, APSR 1990): are U.S. House and Senate standing committees stacked with ideological outliers relative to their parent chamber, or do they mirror it?

The hypotheses, committee classification, sample window, and test were frozen in `PRE_REGISTRATION.md` **before any committee–ideology join was run**.

## What it does

1. `R/01_pull_ideology.R` — DW-NOMINATE dim-1 for all House & Senate members, 103rd–117th Congress, from voteview `HSall_members.csv`.
2. `R/02_pull_committees.R` — Stewart & Woon "Congressional Committee Assignments" (Harvard Dataverse `congdata`), standing committees, 103rd–117th; flags non-voting delegates.
3. `R/03_analysis.R` — joins on `(icpsr, congress)`, enforces the ≥98% completeness gate, then runs the pre-registered committee-vs-chamber median permutation test (10,000 draws), signed displacement, and the aggregate predicted-vs-not-predicted comparison.

Model/test spec is centralized in `R/00_shared.R` (sourced by both `03_analysis.R` and `report.qmd`) so the CLI and the website can never drift.

## Run

```bash
# from the project root
Rscript R/01_pull_ideology.R
Rscript R/02_pull_committees.R
Rscript R/03_analysis.R
quarto render report.qmd
```

Dependencies: `httr`, `jsonlite`, `dplyr`, `tidyr`, `readr`, `stringr`, `tibble`, `readxl`, `ggplot2`.

```r
install.packages(c("httr","jsonlite","dplyr","tidyr","readr",
                   "stringr","tibble","readxl","ggplot2"))
```

## Data sources

- **Committee rosters:** Stewart & Woon, Congressional Committee Assignments — House `10.7910/DVN/XLIHUC`, Senate `10.7910/DVN/EQ6KC7` (Harvard Dataverse).
- **Member ideology:** voteview.com `HSall_members.csv` (DW-NOMINATE).

## The discipline

- Pre-registered; `PRE_REGISTRATION.md` written with no data in hand.
- Completeness gate halts before analysis if any chamber-Congress join is < 98% (see the deviation log for the one documented party-switcher ICPSR crosswalk).
- Result reported honestly against H1, limitations up front (including the permissiveness of the unconstrained-random null and the pre-registered party-stratified follow-up).

See `../PROJECT_BACKLOG.md` for where this sits in the wider portfolio.
