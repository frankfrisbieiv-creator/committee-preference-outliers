# Pre-Registration — Committee Preference Outliers, v2 (Party-Stratified Null)

**Frozen:** 2026-07-01, *before the party-stratified test was run.*
**Status:** this executes the **pre-registered secondary analysis** named in the original committee pre-registration (§7.3: "a party-median variant … sampling within party delegations … is the planned v2"). That secondary was frozen before any data was seen; this document only specifies its exact construction. The v1 *primary* (unconstrained null) result is known; the v2 result is not.

---

## 1. Why v2 exists

The v1 permutation null drew unconstrained random subsets of the chamber. Real committees are built to roughly follow the chamber's party ratio, so unconstrained draws can be far more party-lopsided than any real committee — inflating the null's spread, making committee medians look central, and pushing the outlier rate below the 5% chance floor. That makes v1 a **conservative** test: "not outliers" holds against a null tilted toward finding nothing. v2 removes that slack by conditioning on party composition.

## 2. Question & hypotheses (unchanged from v1)

Are the pre-registered **constituency committees** (House & Senate Agriculture, Armed Services, Natural Resources / Energy, Transportation / Commerce) ideological preference outliers relative to their chamber — **once party composition is held fixed**?

- **H1:** conditional on party, the predicted constituency committees are median outliers more often / more strongly than the not-predicted set (Budget, Rules, Ways & Means / Finance, Appropriations).
- **H0:** conditional on party, predicted and not-predicted committees are indistinguishable from their chamber.

I pre-commit to reporting an H0-consistent result as a finding. Note the directional possibility, given v1: the sharper null may *raise* some committees to outlier status that the permissive null missed — or may confirm the null more convincingly.

## 3. Identification / scope

Descriptive, not causal. This characterizes whether committee rosters are ideologically unrepresentative of their chamber conditional on party; it does not identify *why* (self-selection, leadership assignment, constituency demand are not separated).

## 4. Data (unchanged from v1)

Stewart–Woon committee rosters ⨝ voteview DW-NOMINATE (dim 1) on `(icpsr, congress)`, 103rd–117th Congress, standing committees, voting members with a score. The v1 party-switcher ICPSR crosswalk (Shelby, Campbell, Jeffords) and the ≥98% join-completeness gate **carry over unchanged**; the pipeline halts on any shortfall.

## 5. Test (pre-specified)

**Primary — party-stratified permutation.** For each committee × chamber × Congress:
1. Record the committee's party counts (e.g., 12 D, 10 R).
2. Null draw: sample that many members *within each party* at random from the chamber's members of that party; compute the drawn committee's overall median (dim 1). Repeat N = 10,000.
3. The committee is a "party-stratified median outlier" if its observed median falls outside the central 95% of that null distribution (two-sided).
4. Record signed displacement = committee median − chamber median.

**Secondary — within-party delegation displacement.** For each committee × chamber × Congress × party, test whether the committee's party-delegation median differs from that party's chamber-wide median, via a within-party permutation (N = 10,000 same-size draws from that party's chamber members). This asks directly: *are the Democrats (Republicans) a committee attracts more extreme than the party as a whole?*

**Aggregate test of H1 (both null types):** compare outlier rate and mean |displacement| between the pre-registered predicted set and the not-predicted set, pooled across 103rd–117th, via a permutation test on the difference. Report v2 **side by side with v1** so the effect of tightening the null is visible.

## 6. What would falsify / weaken H1

- Predicted committees are outliers no more often than not-predicted under the stratified null.
- Displacements stay small (same order as v1, ~0.04–0.10) and party-symmetric noise.
- Any significant aggregate difference is again driven by the control set (e.g., House Rules) rather than the predicted constituency committees — in which case it is reported as exploratory, exactly as in v1.

## 7. Known limitations (carried from v1, still binding)

1. **Ideology ≠ constituency demand.** DW-NOMINATE dim 1 is general roll-call ideology. A committee can be constituency-captured (farm, defense) without its members being dim-1 extremists. v2 sharpens the *statistical null*, not this *measurement* validity gap — a committee could be a genuine preference outlier on issue intensity and still look central here. State this plainly; do not let "not outliers on dim 1" become "not captured."
2. Median is one statistic; variance/bimodality differences are out of scope.
3. Coverage ends 2022 (117th).
4. Mid-Congress roster changes collapsed to the Congress level.

## 8. Deliverables

- Reuse `data/committee_panel.csv`; add `data/committee_results_v2.csv` (both null types, per committee-Congress).
- v1-vs-v2 comparison table (outlier rate + mean |displacement|, predicted vs not-predicted, both nulls).
- Updated figure or a v2 panel; a short writeup stating the result against H1 honestly, with the measurement caveat foregrounded.

## Deviation log
- `2026-07-01` — v2 created to execute the pre-registered party-stratified secondary from the original committee pre-registration. No change to hypothesis, committee classification, sample, or data; only the null construction is specified in full here.
