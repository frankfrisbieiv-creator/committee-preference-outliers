#!/usr/bin/env Rscript
# 03_analysis.R  (CLI path; report.qmd renders the same spec for the website)
# Model + test spec live in R/00_shared.R - DO NOT redefine here.
# Run from project root:  Rscript R/03_analysis.R

suppressPackageStartupMessages({ library(dplyr); library(readr) })
source("R/00_shared.R")

ideology <- read_csv("data/ideology.csv", show_col_types = FALSE)
assign0  <- read_csv("data/committee_assignments_raw.csv", show_col_types = FALSE)

# --- 0. Party-switcher ICPSR crosswalk (documented linkage fix) --------------
cat("\n--- Party-switcher ICPSR crosswalk applied (Stewart-Woon -> voteview) ---\n")
print(as.data.frame(ICPSR_CROSSWALK), row.names = FALSE)
assign <- apply_icpsr_crosswalk(assign0)

# --- 1. Completeness gate (halt if any chamber-Congress < 98%) --------------
comp <- completeness_table(assign, ideology)
cat("\n--- Post-fix join completeness: DW-NOMINATE match rate per chamber-Congress ---\n")
print(as.data.frame(comp |> mutate(match_rate = round(match_rate, 4))), row.names = FALSE)

if (any(comp$match_rate < 0.98))
  stop("COMPLETENESS GATE FAILED: ", sum(comp$match_rate < 0.98),
       " chamber-Congress cell(s) below 98% match. Do NOT proceed - investigate the join.")
cat(sprintf("\nGate PASSED: min match rate = %.4f across %d chamber-Congress cells.\n",
            min(comp$match_rate), nrow(comp)))

# --- 2. Build panel + run the pre-registered test per committee x Congress ---
pool  <- chamber_pool(ideology)
panel <- build_committee_panel(assign, ideology)
dir.create("data", showWarnings = FALSE)
write_csv(panel, "data/committee_panel.csv")

results <- run_committee_tests(panel, pool)
write_csv(results, "data/committee_results.csv")

# --- 3. Per-committee outlier rates -----------------------------------------
per_comm <- results |>
  group_by(group, chamber, label) |>
  summarise(n_congresses     = n(),
            n_outlier        = sum(outlier),
            outlier_rate     = round(mean(outlier), 3),
            mean_signed_disp = round(mean(displacement), 3),
            mean_abs_disp    = round(mean(abs_displacement), 3),
            .groups = "drop") |>
  arrange(group, desc(outlier_rate))
cat("\n--- Per-committee outlier rate (share of 15 Congresses flagged) ---\n")
print(as.data.frame(per_comm), row.names = FALSE)

# --- 4. Aggregate H1 test: predicted vs not-predicted, BOTH ways ------------
report_agg <- function(res, tag) {
  a <- aggregate_test(res)
  cat(sprintf("\n[%s]  units: predicted = %d, not-predicted = %d\n",
              tag, sum(res$group == "predicted"), sum(res$group == "not_predicted")))
  cat(sprintf("  Outlier rate   predicted = %.3f  not-predicted = %.3f  diff = %+.3f  (p 1-sided %.4f, 2-sided %.4f)\n",
              a$rate_pred, a$rate_not, a$d_rate, a$p_rate_onesided, a$p_rate_twosided))
  cat(sprintf("  Mean |disp|    predicted = %.3f  not-predicted = %.3f  diff = %+.3f  (p 1-sided %.4f, 2-sided %.4f)\n",
              a$md_pred, a$md_not, a$d_md, a$p_md_onesided, a$p_md_twosided))
}
cat("\n--- Aggregate: predicted-outlier set vs not-predicted set ---")
report_agg(results, "(a) crosswalk applied - full 103-117")
results_b <- results |> filter(!(chamber == "Senate" & congress %in% c(103, 108)))
report_agg(results_b, "(b) Senate 103 & 108 dropped entirely")

cat("\nNumbers only above. Interpret against H1 in PRE_REGISTRATION.md.\n")
