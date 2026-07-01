# Pre-Registration — Are Congressional Committees Preference Outliers?

**Frozen:** 2026-07-01, *before any committee–ideology join was run or inspected.*
**Enforcement:** written with no network access to the data. No committee median had been computed when this spec was fixed.

---

## 1. Question

Are U.S. congressional standing committees composed of **ideological preference outliers** relative to their parent chamber, or do they mirror the chamber? This is the classic distributive-vs-informational debate (Krehbiel, *Are Committees Composed of Preference Outliers?*, APSR 1990; Shepsle–Weingast distributive theory).

## 2. Hypotheses (directional, pre-committed)

Distributive/"gains-from-trade" theory predicts that **constituency-demand committees** are stacked with members whose preferences are unrepresentative of the floor. I pre-commit to classifying these committees as **theory-predicted outliers** *before* seeing results:

- **House & Senate Agriculture**
- **House & Senate Armed Services**
- **House Natural Resources / Senate Energy & Natural Resources** (interior/lands)
- **House Transportation & Infrastructure / Senate Commerce** (public-works demand)

And these as **not predicted to be outliers** (informational/mixed committees expected to track the chamber):

- **Budget, Rules, Ways & Means / Finance, Appropriations**

- **H1:** the theory-predicted committees show committee medians significantly displaced from the chamber median more often than chance, and more often than the not-predicted set.
- **H0:** committee medians are not systematically displaced; predicted and not-predicted sets are indistinguishable.

I will report an H0-consistent result as a finding (it would side with Krehbiel/informational theory), not a failure.

## 3. Data & join (provenance)

| Element | Source | Key |
|---|---|---|
| Committee rosters, by member × committee × Congress | Stewart & Woon, Congressional Committee Assignments (Harvard Dataverse `congdata`) | `icpsr`, `congress` |
| Member ideology (DW-NOMINATE, 1st dimension) | voteview.com `HSall_members.csv` | `icpsr`, `congress` |

The two sources share ICPSR IDs, so the join is on `(icpsr, congress)`. **Join-completeness gate (maker-checker):** the share of committee members successfully matched to a DW-NOMINATE score must be ≥ 98% per chamber-Congress; the pipeline prints the match rate and **halts** if it falls below that, rather than silently analyzing a partial roster. (Lesson carried from Artifact 1: verify completeness before analysis.)

## 4. Sample & unit

- **Window:** 103rd–117th Congress (1993–2022) — the range with clean modern Stewart-Woon coverage. Fixed before results.
- **Unit of analysis:** committee × chamber × Congress.
- **Committees:** standing committees only (exclude select, joint, special, and subcommittees for v1).
- **Members:** voting members with a DW-NOMINATE 1st-dim score; exclude non-voting delegates and any member lacking a score (counted and reported, not dropped silently).
- **Ideology measure:** DW-NOMINATE dimension 1 (economic/liberal–conservative). Dimension 2 out of scope for v1.

## 5. Test (pre-specified)

For each committee × Congress:

1. Compute the **committee median** (dim-1) and the **chamber median** (all voting members of that chamber that Congress).
2. **Outlier test — randomization/permutation:** draw N = 10,000 random subsets of the chamber equal in size to the committee; the committee is a "median outlier" if its observed median falls outside the central 95% of the null distribution of random-subset medians (two-sided). This is non-parametric and makes no distributional assumption.
3. Record signed displacement = committee median − chamber median (positive = more conservative than the floor).

**Aggregate test of H1:** compare the rate of significant outlier status (and mean absolute displacement) between the pre-registered *predicted-outlier* set and the *not-predicted* set, pooled across the window, with a permutation test on the difference. H1 requires the predicted set to be outliers significantly more often / more strongly.

## 6. What would falsify / weaken H1

- Predicted-outlier committees are outliers no more often than the not-predicted set.
- Outlier rates are near the 5% false-positive floor across the board (committees mirror the chamber — Krehbiel's result).
- Displacement direction is inconsistent within a committee across Congresses (noise, not structure).

## 7. Known limitations (stated up front)

1. **Ideology ≠ committee demand.** DW-NOMINATE captures general roll-call ideology, not issue-specific intensity; a committee can be constituency-driven without being an ideological outlier. This tests the *specific* preference-outlier claim, not distributive theory as a whole.
2. **Median is one statistic.** Committees can differ from the floor in variance/bimodality without a median shift; v1 tests medians (the classic quantity) and reports the full distribution visually.
3. **Party-adjusted vs raw.** v1 tests raw chamber-relative outlier status. A party-median variant (are committees outliers *within* their party delegation?) is noted as a pre-registered secondary, not the headline.
4. **Coverage ends 2022 (117th).** Stewart-Woon modern coverage boundary; stated, not hidden.
5. **Assignment ≠ tenure.** Mid-Congress roster changes are collapsed to the Congress level.

## 8. Deliverables

- `data/committee_panel.csv` (member × committee × Congress with DW-NOMINATE, reproducible)
- Per-committee time series of chamber-relative displacement, with outlier flags
- A committee ideology **map/figure** (committees positioned against the chamber median over time)
- The aggregate predicted-vs-not-predicted test
- A short writeup stating the result against H1, honestly, limitations intact.

*Anything decided during analysis and not specified here is labeled exploratory, not confirmatory.*

---

## Deviation log

*This section records post-freezing corrections. The hypotheses (sec 2), committee classification (sec 2), sample window (sec 4), and test (sec 5) are unchanged.*

**2026-07-01 — Party-switcher ICPSR crosswalk (data-linkage correction).**
The join gate (sec 3) correctly halted: two Senate-Congress cells fell below 98% (103rd = 97.9%, 108th = 97.9%). Cause: voteview assigns a member who switches party a new ICPSR (1↔9 leading digit) while the Stewart-Woon file keeps a single ID, so the `(icpsr, congress)` join missed three members who *do* have verified DW-NOMINATE scores under the other ID:

| Member | State | Congress | Stewart-Woon ICPSR | voteview ICPSR | Party switch |
|---|---|---|---|---|---|
| Shelby, Richard C. | AL | 103 | 94659 | 14659 | D→R (1994) |
| Campbell, Ben Nighthorse | CO | 108 | 15407 | 95407 | D→R (1995) |
| Jeffords, James M. | VT | 108 | 14240 | 94240 | R→I (2001) |

Resolution: map Stewart-Woon → voteview ICPSR for these member-Congresses (same person, verified by name/state), so each is matched to their true score. This is a measurement/linkage correction, orthogonal to the hypothesis — it gives real members their real ideology values; it is not a researcher degree of freedom over the result. **Lloyd Bentsen** (103rd, ICPSR 660) is *not* crosswalked: he resigned days into the Congress and has no DW-NOMINATE score, so the gate correctly excludes him as genuinely scoreless.

Robustness: the aggregate predicted-vs-not-predicted test is reported both with the crosswalk applied and with the 103rd/108th Senate dropped entirely, to confirm these three members do not drive the finding.
