#!/usr/bin/env Rscript
# 01_pull_ideology.R
# Pulls DW-NOMINATE (1st dimension) for all House & Senate members, 103rd-117th
# Congress, from voteview's HSall_members.csv (no key). One row per member x
# congress x chamber. This is the ideology side of the (icpsr, congress) join.
#
# Output: data/ideology.csv
# Run from project root:  Rscript R/01_pull_ideology.R

suppressPackageStartupMessages({ library(readr); library(dplyr) })

URL <- "https://voteview.com/static/data/out/members/HSall_members.csv"
WINDOW <- 103:117

message("Downloading voteview HSall_members.csv ...")
m <- read_csv(URL, show_col_types = FALSE)

id <- m |>
  filter(congress %in% WINDOW, chamber %in% c("House", "Senate")) |>
  transmute(congress, chamber, icpsr,
            state_abbrev, party_code, bioname,
            nominate_dim1)

# Loud sanity: expect ~535 (House) + ~100 (Senate) members per congress.
if (nrow(id) < 15 * 600)
  warning(sprintf("Only %d member-rows for 103-117 - lower than expected ~%d",
                  nrow(id), 15 * 635))

n_na <- sum(is.na(id$nominate_dim1))
message(sprintf("Members 103-117: %d rows (%d House, %d Senate). Missing dim-1 score: %d",
                nrow(id), sum(id$chamber == "House"), sum(id$chamber == "Senate"), n_na))

dir.create("data", showWarnings = FALSE)
write_csv(id, "data/ideology.csv")
message("Wrote data/ideology.csv")
