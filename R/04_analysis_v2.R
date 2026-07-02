#!/usr/bin/env Rscript
# 04_analysis_v2.R  -- Party-stratified null (PRE_REGISTRATION_v2.md)
# Reuses R/00_shared.R for the crosswalk, the >=98% completeness gate, and the
# chamber pool UNCHANGED. Adds the two v2 nulls (party-stratified primary,
# within-party delegation secondary). Numbers only; no writeup, no figure.
#
# CONVENTION (matched to v1): v1's perm_outlier() samples k members from the
# FULL chamber pool via sample(chamber_scores, k, replace=FALSE) and does NOT
# remove the committee's own members. v2 therefore also samples WITHOUT
# replacement from the same-chamber, same-Congress, same-party pool WITHOUT
# excluding the committee's own members (the pool includes them).

suppressPackageStartupMessages({ library(dplyr); library(readr); library(tibble) })
source("R/00_shared.R")

ideology <- read_csv("data/ideology.csv", show_col_types = FALSE)
assign0  <- read_csv("data/committee_assignments_raw.csv", show_col_types = FALSE)

# --- 0. Party-switcher ICPSR crosswalk (unchanged from v1) -------------------
assign <- apply_icpsr_crosswalk(assign0)

# --- 1. Completeness gate (unchanged from v1; must still pass) ---------------
comp <- completeness_table(assign, ideology)
cat("\n=== [1] Post-fix join completeness: DW-NOMINATE match rate per chamber-Congress ===\n")
print(as.data.frame(comp |> mutate(match_rate = round(match_rate, 4))), row.names = FALSE)
if (any(comp$match_rate < 0.98))
  stop("COMPLETENESS GATE FAILED: ", sum(comp$match_rate < 0.98), " cell(s) below 98%.")
cat(sprintf("\nGate PASSED: min match rate = %.4f across %d chamber-Congress cells.\n",
            min(comp$match_rate), nrow(comp)))

# --- 2. Reuse existing panel; attach party from ideology --------------------
panel <- read_csv("data/committee_panel.csv", show_col_types = FALSE)

# Party label for every scored chamber member (100=D, 200=R, 328=I -> "I").
party_of <- function(code) ifelse(code == 100L, "D", ifelse(code == 200L, "R", "I"))
pool_party <- ideology |>
  filter(chamber %in% c("House", "Senate"), !is.na(nominate_dim1)) |>
  distinct(congress, chamber, icpsr, .keep_all = TRUE) |>
  transmute(congress, chamber, icpsr, nominate_dim1, party = party_of(party_code))

# Committee members with party (panel already carries the crosswalked icpsr).
panel_p <- panel |>
  left_join(pool_party |> select(congress, chamber, icpsr, party),
            by = c("congress", "chamber", "icpsr"))
stopifnot(!any(is.na(panel_p$party)))   # every committee member must resolve a party

# --- Pool sizes for two example committee-Congresses (sanity check) ---------
show_pool <- function(lab, cong) {
  cs <- panel_p |> filter(label == lab, congress == cong)
  ch <- pool_party |> filter(chamber == cs$chamber[1], congress == cong)
  comm_counts <- table(factor(cs$party, levels = c("D", "R", "I")))
  pool_counts <- table(factor(ch$party, levels = c("D", "R", "I")))
  cat(sprintf("\n  %s, %dth Congress (%s):\n", lab, cong, cs$chamber[1]))
  cat(sprintf("    committee needs : D=%d  R=%d  I=%d  (total %d)\n",
              comm_counts["D"], comm_counts["R"], comm_counts["I"], nrow(cs)))
  cat(sprintf("    chamber-party pool to draw from (incl. committee's own): D=%d  R=%d  I=%d  (total %d)\n",
              pool_counts["D"], pool_counts["R"], pool_counts["I"], nrow(ch)))
}
cat("\n=== [2] Example pool sizes (party-stratified draw; pool INCLUDES committee's own members, matching v1) ===\n")
show_pool("House Agriculture", 110)
show_pool("Senate Finance", 114)

# --- 3. Party-stratified primary + within-party secondary -------------------
# Primary: draw committee's exact per-party counts from the chamber-party pool
#   (without replacement, pool includes committee members), take OVERALL median.
# Secondary: per party, does the committee's party-delegation median differ from
#   that party's chamber-wide median (within-party permutation).
strat_null_median <- function(pool_by_party, counts, n_perm) {
  parties <- names(counts)
  replicate(n_perm, {
    drawn <- unlist(lapply(parties, function(p)
      sample(pool_by_party[[p]], counts[[p]], replace = FALSE)), use.names = FALSE)
    median(drawn)
  })
}

units <- panel_p |> distinct(chamber, committee_code, label, group, congress) |>
  arrange(group, chamber, committee_code, congress)

set.seed(SEED)
prim_rows <- list(); wp_rows <- list()
for (i in seq_len(nrow(units))) {
  u  <- units[i, ]
  cs <- panel_p |> filter(chamber == u$chamber, committee_code == u$committee_code,
                          congress == u$congress)
  ch <- pool_party |> filter(chamber == u$chamber, congress == u$congress)

  counts <- as.list(table(factor(cs$party, levels = c("D", "R", "I"))))
  counts <- counts[vapply(counts, function(x) x > 0, logical(1))]   # only parties present
  pool_by_party <- split(ch$nominate_dim1, ch$party)

  obs      <- median(cs$nominate_dim1)
  ch_med   <- median(ch$nominate_dim1)
  null_med <- strat_null_median(pool_by_party, counts, N_PERM)
  lo <- unname(quantile(null_med, 0.025)); hi <- unname(quantile(null_med, 0.975))
  p  <- (1 + sum(abs(null_med - ch_med) >= abs(obs - ch_med))) / (N_PERM + 1)

  prim_rows[[i]] <- tibble(
    test = "stratified_primary", stratum = "overall",
    chamber = u$chamber, label = u$label, group = u$group, congress = u$congress,
    committee_n = nrow(cs), n_D = sum(cs$party == "D"), n_R = sum(cs$party == "R"),
    n_I = sum(cs$party == "I"), chamber_n = nrow(ch),
    committee_median = obs, chamber_median = ch_med,
    displacement = obs - ch_med, abs_displacement = abs(obs - ch_med),
    ci_lo = lo, ci_hi = hi, outlier = (obs < lo) | (obs > hi), p_value = p)

  # Secondary: within-party delegation displacement
  for (pty in names(counts)) {
    k        <- counts[[pty]]
    ppool    <- pool_by_party[[pty]]
    obs_p    <- median(cs$nominate_dim1[cs$party == pty])
    party_md <- median(ppool)
    null_p   <- replicate(N_PERM, median(sample(ppool, k, replace = FALSE)))
    lo_p <- unname(quantile(null_p, 0.025)); hi_p <- unname(quantile(null_p, 0.975))
    pv_p <- (1 + sum(abs(null_p - party_md) >= abs(obs_p - party_md))) / (N_PERM + 1)
    wp_rows[[length(wp_rows) + 1]] <- tibble(
      test = "within_party", stratum = pty,
      chamber = u$chamber, label = u$label, group = u$group, congress = u$congress,
      committee_n = k, n_D = NA_integer_, n_R = NA_integer_, n_I = NA_integer_,
      chamber_n = length(ppool),
      committee_median = obs_p, chamber_median = party_md,
      displacement = obs_p - party_md, abs_displacement = abs(obs_p - party_md),
      ci_lo = lo_p, ci_hi = hi_p, outlier = (obs_p < lo_p) | (obs_p > hi_p), p_value = pv_p)
  }
}
primary <- bind_rows(prim_rows)
within_party <- bind_rows(wp_rows)

results_v2 <- bind_rows(primary, within_party)
write_csv(results_v2, "data/committee_results_v2.csv")

# --- 4. Per-committee outlier rates under the STRATIFIED (primary) null ------
per_comm <- primary |>
  group_by(group, chamber, label) |>
  summarise(n_congresses = n(), n_outlier = sum(outlier),
            outlier_rate = round(mean(outlier), 3),
            mean_signed_disp = round(mean(displacement), 3),
            mean_abs_disp = round(mean(abs_displacement), 3), .groups = "drop") |>
  arrange(group, desc(outlier_rate))
cat("\n=== [3] Per-committee outlier rate under PARTY-STRATIFIED null (share of Congresses flagged) ===\n")
print(as.data.frame(per_comm), row.names = FALSE)

# --- 5. Within-party delegation displacement results ------------------------
per_wp <- within_party |>
  group_by(group, chamber, label, stratum) |>
  summarise(n = n(), n_outlier = sum(outlier), outlier_rate = round(mean(outlier), 3),
            mean_signed_disp = round(mean(displacement), 3),
            mean_abs_disp = round(mean(abs_displacement), 3), .groups = "drop") |>
  arrange(group, chamber, label, stratum)
cat("\n=== [4] Within-party delegation displacement (committee party-median vs party chamber-median) ===\n")
print(as.data.frame(per_wp), row.names = FALSE)

wp_by_party <- within_party |>
  group_by(group, stratum) |>
  summarise(n = n(), outlier_rate = round(mean(outlier), 3),
            mean_abs_disp = round(mean(abs_displacement), 3), .groups = "drop")
cat("\n  Pooled within-party by group x party:\n")
print(as.data.frame(wp_by_party), row.names = FALSE)

# --- 6. v1-vs-v2 aggregate comparison (predicted vs not-predicted) ----------
v1 <- read_csv("data/committee_results.csv", show_col_types = FALSE)
agg_line <- function(res) {
  a <- aggregate_test(res)
  list(rate_pred = a$rate_pred, rate_not = a$rate_not, d_rate = a$d_rate,
       p_rate = a$p_rate_onesided, md_pred = a$md_pred, md_not = a$md_not,
       d_md = a$d_md, p_md = a$p_md_onesided)
}
a1 <- agg_line(v1)
a2 <- agg_line(primary)

cat("\n=== [5] v1 (unconstrained null) vs v2 (party-stratified null), predicted vs not-predicted ===\n")
cmp <- tibble(
  null = c("v1_unconstrained", "v2_party_stratified"),
  outlier_rate_pred = round(c(a1$rate_pred, a2$rate_pred), 3),
  outlier_rate_not  = round(c(a1$rate_not,  a2$rate_not),  3),
  outlier_rate_diff = round(c(a1$d_rate,    a2$d_rate),    3),
  p_rate_1sided     = round(c(a1$p_rate,    a2$p_rate),    4),
  mean_absdisp_pred = round(c(a1$md_pred,   a2$md_pred),   3),
  mean_absdisp_not  = round(c(a1$md_not,    a2$md_not),    3),
  mean_absdisp_diff = round(c(a1$d_md,      a2$d_md),      3),
  p_md_1sided       = round(c(a1$p_md,      a2$p_md),      4))
print(as.data.frame(cmp), row.names = FALSE)

cat("\nWrote data/committee_results_v2.csv (", nrow(results_v2), " rows: ",
    nrow(primary), " primary + ", nrow(within_party), " within-party).\n", sep = "")
cat("Numbers only. No interpretation.\n")
