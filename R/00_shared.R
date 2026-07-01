#!/usr/bin/env Rscript
# 00_shared.R
# Single source of truth for the PRE-REGISTERED committee-outlier spec. Sourced by
# 03_analysis.R (CLI) and report.qmd (website) so the spec can never drift.
# See PRE_REGISTRATION.md sections 2 (classification), 4 (sample), 5 (test).

suppressPackageStartupMessages({ library(dplyr); library(tibble); library(ggplot2) })

WINDOW <- 103:117
N_PERM <- 10000L          # permutation draws (PRE_REGISTRATION.md sec 5)
SEED   <- 20260701L       # fixed so the permutation results are reproducible

# --- Pre-registered committee classification (frozen before results) --------
# Identified by Stewart-Woon committee CODE (stable across the many name changes
# in the window; see the dataset codebook). group is the pre-committed label.
COMMITTEES <- tribble(
  ~chamber, ~committee_code, ~label,                                   ~group,
  "House",  102L, "House Agriculture",                                 "predicted",
  "Senate", 305L, "Senate Agriculture",                               "predicted",
  "House",  106L, "House Armed Services",                              "predicted",
  "Senate", 308L, "Senate Armed Services",                            "predicted",
  "House",  164L, "House Natural Resources",                          "predicted",
  "Senate", 330L, "Senate Energy & Natural Resources",               "predicted",
  "House",  173L, "House Transportation & Infrastructure",           "predicted",
  "Senate", 321L, "Senate Commerce",                                  "predicted",
  "House",  115L, "House Budget",                                      "not_predicted",
  "Senate", 316L, "Senate Budget",                                     "not_predicted",
  "House",  176L, "House Rules",                                       "not_predicted",
  "Senate", 380L, "Senate Rules & Administration",                    "not_predicted",
  "House",  196L, "House Ways & Means",                                "not_predicted",
  "Senate", 336L, "Senate Finance",                                    "not_predicted",
  "House",  104L, "House Appropriations",                              "not_predicted",
  "Senate", 306L, "Senate Appropriations",                            "not_predicted"
)

# --- Party-switcher ICPSR crosswalk (deviation note 2026-07-01) --------------
# voteview assigns a member who switches party a new ICPSR (1<->9 leading digit),
# while the Stewart-Woon file keeps a single ID. For the affected member-Congresses
# this breaks the (icpsr, congress) join even though the member has a verified
# DW-NOMINATE score under the other ID. Map Stewart-Woon ID -> voteview ID so each
# is matched to their true score. Verified same person by name/state. This is a
# data-linkage correction, orthogonal to the hypothesis; see PRE_REGISTRATION.md
# deviation log. (Lloyd Bentsen, 103rd, is NOT here: he resigned immediately and
# is genuinely scoreless, so the gate correctly excludes him.)
ICPSR_CROSSWALK <- tribble(
  ~congress, ~from_icpsr, ~to_icpsr, ~member,                    ~state, ~switch,
  103L,      94659L,      14659L,    "Shelby, Richard C.",       "AL",   "D->R (1994)",
  108L,      15407L,      95407L,    "Campbell, Ben Nighthorse", "CO",   "D->R (1995)",
  108L,      14240L,      94240L,    "Jeffords, James M.",       "VT",   "R->I (2001)"
)
apply_icpsr_crosswalk <- function(assign) {
  assign |>
    left_join(ICPSR_CROSSWALK |> select(congress, from_icpsr, to_icpsr),
              by = c("congress", "icpsr" = "from_icpsr")) |>
    mutate(icpsr = ifelse(is.na(to_icpsr), icpsr, to_icpsr)) |>
    select(-to_icpsr)
}

# --- Chamber ideology pool: voting members with a dim-1 score ----------------
# One row per (congress, chamber, member). This is the reference distribution the
# committee is tested against (all voting members of the chamber that Congress).
chamber_pool <- function(ideology) {
  ideology |>
    filter(chamber %in% c("House", "Senate"), !is.na(nominate_dim1)) |>
    distinct(congress, chamber, icpsr, .keep_all = TRUE) |>
    select(congress, chamber, icpsr, nominate_dim1)
}

# --- Join-completeness gate (maker-checker, PRE_REGISTRATION.md sec 3) -------
# Of the VOTING members on the classified committees, what share matched a
# DW-NOMINATE score, per chamber x Congress? Delegates are excluded (sec 4).
completeness_table <- function(assign, ideology) {
  scores <- chamber_pool(ideology) |> distinct(congress, chamber, icpsr) |>
    mutate(has_score = TRUE)
  assign |>
    filter(!is_delegate) |>
    semi_join(COMMITTEES, by = c("chamber", "committee_code")) |>
    distinct(congress, chamber, icpsr) |>
    left_join(scores, by = c("congress", "chamber", "icpsr")) |>
    mutate(has_score = !is.na(has_score)) |>
    group_by(chamber, congress) |>
    summarise(members = n(), matched = sum(has_score),
              match_rate = matched / members, .groups = "drop") |>
    arrange(chamber, congress)
}

# --- Committee membership panel (voting members with scores) -----------------
# One row per (congress, chamber, committee, member), collapsed across mid-Congress
# roster changes (PRE_REGISTRATION.md sec 4/7).
build_committee_panel <- function(assign, ideology) {
  scores <- chamber_pool(ideology)
  assign |>
    filter(!is_delegate) |>
    semi_join(COMMITTEES, by = c("chamber", "committee_code")) |>
    distinct(congress, chamber, committee_code, icpsr) |>
    inner_join(scores, by = c("congress", "chamber", "icpsr")) |>
    inner_join(COMMITTEES, by = c("chamber", "committee_code"))
}

# --- Two-sided permutation outlier test (PRE_REGISTRATION.md sec 5) ----------
# Draw N random chamber subsets equal in size to the committee; the committee is a
# "median outlier" if its observed median falls outside the central 95% of the
# null distribution of random-subset medians.
perm_outlier <- function(committee_scores, chamber_scores, n_perm = N_PERM) {
  k   <- length(committee_scores)
  obs <- median(committee_scores)
  ctr <- median(chamber_scores)
  null_med <- replicate(n_perm, median(sample(chamber_scores, k, replace = FALSE)))
  lo <- unname(quantile(null_med, 0.025)); hi <- unname(quantile(null_med, 0.975))
  p  <- (1 + sum(abs(null_med - ctr) >= abs(obs - ctr))) / (n_perm + 1)  # 2-sided empirical
  list(committee_median = obs, chamber_median = ctr, displacement = obs - ctr,
       ci_lo = lo, ci_hi = hi, outlier = (obs < lo) | (obs > hi), p_value = p)
}

# --- Run the test for every committee x Congress ----------------------------
run_committee_tests <- function(panel, pool, n_perm = N_PERM, seed = SEED) {
  set.seed(seed)
  units <- panel |> distinct(chamber, committee_code, label, group, congress) |>
    arrange(group, chamber, committee_code, congress)
  rows <- lapply(seq_len(nrow(units)), function(i) {
    u  <- units[i, ]
    cs <- panel$nominate_dim1[panel$chamber == u$chamber &
                              panel$committee_code == u$committee_code &
                              panel$congress == u$congress]
    ch <- pool$nominate_dim1[pool$chamber == u$chamber & pool$congress == u$congress]
    r  <- perm_outlier(cs, ch, n_perm)
    tibble(chamber = u$chamber, label = u$label, group = u$group, congress = u$congress,
           committee_n = length(cs), chamber_n = length(ch),
           committee_median = r$committee_median, chamber_median = r$chamber_median,
           displacement = r$displacement, abs_displacement = abs(r$displacement),
           ci_lo = r$ci_lo, ci_hi = r$ci_hi, outlier = r$outlier, p_value = r$p_value)
  })
  bind_rows(rows)
}

# --- Aggregate H1 test: predicted vs not-predicted --------------------------
# Compare outlier rate and mean |displacement| between the pre-registered sets,
# pooled across the window, with a label-permutation test on the difference.
# H1 is directional (predicted MORE), so the reported p is one-sided in that
# direction; the two-sided p is also returned.
aggregate_test <- function(results, n_perm = N_PERM, seed = SEED) {
  set.seed(seed + 1L)
  pr <- results$group == "predicted"
  rate_pred <- mean(results$outlier[pr]);           rate_not <- mean(results$outlier[!pr])
  md_pred   <- mean(results$abs_displacement[pr]);  md_not   <- mean(results$abs_displacement[!pr])
  d_rate <- rate_pred - rate_not; d_md <- md_pred - md_not
  n <- nrow(results); npred <- sum(pr)
  perm <- replicate(n_perm, {
    idx <- sample(n, npred)
    c(mean(results$outlier[idx])          - mean(results$outlier[-idx]),
      mean(results$abs_displacement[idx]) - mean(results$abs_displacement[-idx]))
  })
  list(
    rate_pred = rate_pred, rate_not = rate_not, d_rate = d_rate,
    p_rate_onesided = (1 + sum(perm[1, ] >= d_rate)) / (n_perm + 1),
    p_rate_twosided = (1 + sum(abs(perm[1, ]) >= abs(d_rate))) / (n_perm + 1),
    md_pred = md_pred, md_not = md_not, d_md = d_md,
    p_md_onesided = (1 + sum(perm[2, ] >= d_md)) / (n_perm + 1),
    p_md_twosided = (1 + sum(abs(perm[2, ]) >= abs(d_md))) / (n_perm + 1)
  )
}

# --- Figure: committee-vs-chamber displacement over time --------------------
# Each line is one committee's signed displacement (committee median - chamber
# median, DW-NOMINATE dim 1) across the window; 0 is the chamber median.
make_displacement_plot <- function(results) {
  ggplot(results, aes(congress, displacement, group = label, color = group)) +
    geom_hline(yintercept = 0, linewidth = 0.4, color = "grey40") +
    geom_line(alpha = 0.6) +
    geom_point(size = 1.1, alpha = 0.8) +
    scale_color_manual(values = c(predicted = "#d95f0e", not_predicted = "#2c7fb8"),
                       labels = c(predicted = "Predicted outlier (constituency)",
                                  not_predicted = "Not predicted (control)")) +
    facet_wrap(~chamber) +
    labs(title = "Committee median minus chamber median, 103rd-117th Congress",
         subtitle = "DW-NOMINATE dim 1; 0 = exactly the chamber median. Each line is a committee.",
         x = "Congress", y = "Signed displacement (committee - chamber)", color = NULL) +
    theme_minimal(base_size = 12) +
    theme(legend.position = "bottom")
}
