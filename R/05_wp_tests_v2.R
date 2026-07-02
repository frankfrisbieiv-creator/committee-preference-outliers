#!/usr/bin/env Rscript
# 05_wp_tests_v2.R -- follow-on numbers on the v2 within-party results. No writeup.
suppressPackageStartupMessages({ library(dplyr); library(readr) })
source("R/00_shared.R")

res <- read_csv("data/committee_results_v2.csv", show_col_types = FALSE)
wp  <- res |> filter(test == "within_party")

# --- Permutation test: predicted vs not-predicted in within-party OUTLIER RATE
perm_diff <- function(d, n_perm = N_PERM, seed = SEED) {
  set.seed(seed)
  pr <- d$group == "predicted"
  obs <- mean(d$outlier[pr]) - mean(d$outlier[!pr])
  n <- nrow(d); npred <- sum(pr)
  perm <- replicate(n_perm, {
    idx <- sample(n, npred)
    mean(d$outlier[idx]) - mean(d$outlier[-idx])
  })
  list(rate_pred = mean(d$outlier[pr]), rate_not = mean(d$outlier[!pr]),
       n_pred = npred, n_not = n - npred, diff = obs,
       p_1sided = (1 + sum(perm >= obs)) / (n_perm + 1),
       p_2sided = (1 + sum(abs(perm) >= abs(obs))) / (n_perm + 1))
}

cat("=== [A] Confirmatory: predicted vs not-predicted within-party outlier rate (pooled across parties) ===\n")
a <- perm_diff(wp)
cat(sprintf("  rate predicted = %.3f (n=%d)   not-predicted = %.3f (n=%d)   diff = %+.3f   p 1-sided = %.4f   2-sided = %.4f\n",
            a$rate_pred, a$n_pred, a$rate_not, a$n_not, a$diff, a$p_1sided, a$p_2sided))

cat("\n=== [B] EXPLORATORY: same test split by party ===\n")
for (pty in c("D", "R")) {
  b <- perm_diff(wp |> filter(stratum == pty))
  cat(sprintf("  %s: predicted = %.3f (n=%d)   not-predicted = %.3f (n=%d)   diff = %+.3f   p 1-sided = %.4f   2-sided = %.4f\n",
              pty, b$rate_pred, b$n_pred, b$rate_not, b$n_not, b$diff, b$p_1sided, b$p_2sided))
}

# --- Signed within-party displacement (committee party median - party chamber median)
cat("\n=== [C] Mean SIGNED within-party displacement (neg = more liberal) by group x party ===\n")
sg <- wp |> group_by(group, stratum) |>
  summarise(n = n(), mean_signed_disp = round(mean(displacement), 3),
            mean_abs_disp = round(mean(abs_displacement), 3), .groups = "drop")
print(as.data.frame(sg), row.names = FALSE)

cat("\n=== [D] Mean SIGNED displacement for the four named committee delegations ===\n")
named <- tibble::tribble(
  ~label,                    ~stratum,
  "House Agriculture",       "D",
  "House Armed Services",    "D",
  "House Appropriations",    "R",
  "Senate Budget",           "R")
nd <- wp |> semi_join(named, by = c("label", "stratum")) |>
  group_by(label, stratum) |>
  summarise(n = n(), n_outlier = sum(outlier), outlier_rate = round(mean(outlier), 3),
            mean_signed_disp = round(mean(displacement), 3),
            mean_abs_disp = round(mean(abs_displacement), 3), .groups = "drop")
# preserve requested order
nd <- named |> left_join(nd, by = c("label", "stratum"))
print(as.data.frame(nd), row.names = FALSE)

cat("\nNumbers only.\n")
