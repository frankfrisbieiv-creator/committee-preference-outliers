#!/usr/bin/env Rscript
# 02_pull_committees.R
# Pulls Stewart & Woon "Congressional Committee Assignments" (Harvard Dataverse
# `congdata`) for the 103rd-117th Congress, both chambers, and flags non-voting
# delegates/resident commissioners (from the companion member files) so the
# analysis can exclude them per the pre-registration.
#
#   House committee assignments : DOI 10.7910/DVN/XLIHUC  (House_assignments_103-117.xls)
#   Senate committee assignments: DOI 10.7910/DVN/EQ6KC7  (Senate_assignments_103-117.tab)
#
# Both assignment files carry a "Last Update ..." banner in row 1 and the real
# column header in row 2 (hence skip = 1). Confirmed columns: Congress,
# "Committee code"/"Committee Code", "ID #" (= ICPSR), ..., "Committee Name".
# Delegate status comes from the member files' Office field (7 = Delegate,
# 8 = Resident Commissioner; House only).
#
# Output: data/committee_assignments_raw.csv
# Run from project root:  Rscript R/02_pull_committees.R

suppressPackageStartupMessages({
  library(httr); library(readxl); library(dplyr); library(readr); library(stringr)
})

BASE <- "https://dataverse.harvard.edu/api/access/datafile"
# fileIds resolved from the dataverse API (dataset versions above).
FID <- list(house_assign = 4640702,   # .xls (raw)
            senate_assign = 4640697,   # ingested xlsx -> pull ?format=original
            house_members = 4640701,   # ingested xlsx (Office codes)
            senate_members = 4640698)  # ingested xlsx (Office codes)

tmp <- file.path(tempdir(), "sw")
dir.create(tmp, showWarnings = FALSE)
grab <- function(fid, dest, original = FALSE) {
  u <- sprintf("%s/%d%s", BASE, fid, if (original) "?format=original" else "")
  r <- GET(u, write_disk(file.path(tmp, dest), overwrite = TRUE))
  if (status_code(r) != 200) stop("download failed for fileId ", fid, ": HTTP ", status_code(r))
  file.path(tmp, dest)
}

message("Downloading Stewart-Woon assignment + member files ...")
f_h  <- grab(FID$house_assign,  "house_assign.xls")
f_s  <- grab(FID$senate_assign, "senate_assign.xlsx", original = TRUE)
f_hm <- grab(FID$house_members, "house_members.xlsx", original = TRUE)
f_sm <- grab(FID$senate_members,"senate_members.xlsx", original = TRUE)

# --- assignment files: skip banner row, take row 2 as header --------------
read_assign <- function(path, chamber) {
  raw <- read_excel(path, skip = 1, col_names = TRUE, .name_repair = "minimal")
  names(raw) <- str_squish(tolower(names(raw)))
  # tolerate "committee code" vs "committee Code" etc.
  cc <- names(raw)[str_detect(names(raw), "^committee code$")][1]
  id <- names(raw)[str_detect(names(raw), "^id")][1]
  cn <- names(raw)[str_detect(names(raw), "^committee name$")][1]
  cg <- names(raw)[str_detect(names(raw), "^cong")][1]
  tibble(
    congress       = suppressWarnings(as.integer(raw[[cg]])),
    chamber        = chamber,
    committee_code = suppressWarnings(as.integer(raw[[cc]])),
    icpsr          = suppressWarnings(as.integer(raw[[id]])),
    committee_name = as.character(raw[[cn]])
  ) |> filter(!is.na(congress), !is.na(committee_code), !is.na(icpsr))
}

assign <- bind_rows(read_assign(f_h, "House"), read_assign(f_s, "Senate")) |>
  filter(congress %in% 103:117)

# --- member files: Office field -> delegate flag --------------------------
read_office <- function(path) {
  raw <- read_excel(path, skip = 1, col_names = TRUE, .name_repair = "minimal")
  names(raw) <- str_squish(tolower(names(raw)))
  cg  <- names(raw)[str_detect(names(raw), "^cong")][1]    # "cong" (House) / "congress" (Senate)
  id  <- names(raw)[str_detect(names(raw), "^id")][1]       # "id" / "id#"
  off <- names(raw)[str_detect(names(raw), "^office")][1]
  tibble(congress = suppressWarnings(as.integer(raw[[cg]])),
         icpsr    = suppressWarnings(as.integer(raw[[id]])),
         office   = suppressWarnings(as.integer(raw[[off]]))) |>
    filter(!is.na(congress), !is.na(icpsr))
}
members <- bind_rows(read_office(f_hm), read_office(f_sm)) |>
  distinct(congress, icpsr, .keep_all = TRUE) |>
  mutate(is_delegate = office %in% c(7L, 8L))  # 7 Delegate, 8 Resident Commissioner

assign <- assign |>
  left_join(select(members, congress, icpsr, is_delegate), by = c("congress", "icpsr")) |>
  mutate(is_delegate = ifelse(is.na(is_delegate), FALSE, is_delegate))

# Known single mis-key in the source file: one 113th-Senate row carries Commerce's
# code (321) but the name "Homeland Security and Governmental Affairs" (correctly
# code 344, out of scope). Drop it so it can't contaminate Senate Commerce.
badkey <- with(assign, chamber == "Senate" & committee_code == 321L &
                 str_detect(str_to_lower(committee_name), "homeland|governmental"))
if (any(badkey)) {
  message(sprintf("Dropping %d mis-keyed row(s): code 321 named Homeland/Governmental.", sum(badkey)))
  assign <- assign[!badkey, ]
}

message(sprintf("Assignment rows 103-117: %d (House %d, Senate %d). Delegate rows: %d",
                nrow(assign), sum(assign$chamber == "House"),
                sum(assign$chamber == "Senate"), sum(assign$is_delegate)))

dir.create("data", showWarnings = FALSE)
write_csv(assign, "data/committee_assignments_raw.csv")
message("Wrote data/committee_assignments_raw.csv")
