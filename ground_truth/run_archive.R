# coppock_mcclellan_2019/ground_truth/run_archive.R
# Output: ground_truth/archive_run_status.csv, ground_truth/archive_overwrites.csv
# Depends on: original/ (run download_original.R first)
# Description: Runs every deposited script, twice, and records whether each one reaches
#   its last line and what it does to the files around it.
#
#   Each pass works in a scratch copy of the deposit, never in original/, so a script
#   that writes into its working directory cannot alter the deposited bytes. The
#   as_shipped pass copies all 29 deposited files. The stripped pass copies code and
#   data only, leaving out the two R history files and README.txt; no deposited file is
#   an intermediate that deposited code builds, so nothing is withheld that a script
#   could rebuild.
#
#   Every script runs in a fresh R process under source(), from the scratch directory,
#   since each one names its helper file and its data by bare relative path. LucidValidationHelperFunctions.R is
#   only ever sourced by the numbered scripts, so it gets no row of its own.
#
#   archive_overwrites.csv records every file a pass added, wrote over, or deleted, and
#   holds no rows when a pass leaves the scratch copy exactly as it found it.
#
#   This script is not part of run_all.R. It needs the packages the deposit was written
#   against (stargazer, xtable, coefplot, reshape2), which the maintained rewrite does
#   not use, and its two tables are committed.

library(here)
library(tidyverse)
library(processx)

here::i_am("ground_truth/run_archive.R")

deposit_dir <- here::here("original", "ReplicationArchive")
deposited <- list.files(deposit_dir, all.files = TRUE, no.. = TRUE)

stopifnot(length(deposited) == 29)

scripts <- str_subset(deposited, "^[0-9]{2}_.*[.]R$")
code_and_data <- str_subset(deposited, "[.](R|RData|rdata|rds)$")

stopifnot(length(scripts) == 12, "LucidValidationHelperFunctions.R" %in% code_and_data)

passes <- list(as_shipped = deposited, stripped = code_and_data)

# File state ----
# A file is identified by its checksum and its modification time, so a script that
# writes a file back with the same bytes is still caught writing it.
file_state <- function(dir) {
  paths <- list.files(dir, all.files = TRUE, no.. = TRUE, full.names = TRUE)
  tibble(
    file = basename(paths),
    md5 = unname(tools::md5sum(paths)),
    mtime = file.mtime(paths)
  )
}

# The last error R reports, on one line. NA for a script that reaches its last line.
error_text <- function(stderr) {
  lines <- read_lines(I(stderr))
  first_error <- str_which(lines, "^Error")
  if (length(first_error) == 0) {
    return(NA_character_)
  }
  lines[first_error[1]:length(lines)] |>
    str_squish() |>
    str_c(collapse = " ") |>
    str_trunc(300)
}

# Passes ----
run_pass <- function(pass, files) {
  scratch <- file.path(tempdir(), str_glue("coppock_mcclellan_2019_{pass}"))
  unlink(scratch, recursive = TRUE)
  dir.create(scratch)
  stopifnot(all(file.copy(file.path(deposit_dir, files), scratch, copy.date = TRUE)))

  before <- file_state(scratch)

  status <- map(scripts, function(script) {
    result <- processx::run(
      "Rscript", c("-e", str_glue("source('{script}')")),
      wd = scratch, error_on_status = FALSE, timeout = 1800
    )
    tibble(
      pass = pass,
      script = script,
      exit_status = result$status,
      timed_out = result$timeout,
      stopped_at = error_text(result$stderr)
    )
  }) |>
    list_rbind()

  after <- file_state(scratch)

  touched <- full_join(before, after, by = "file", suffix = c("_before", "_after")) |>
    mutate(
      effect = case_when(
        is.na(md5_before) ~ "added",
        is.na(md5_after) ~ "deleted",
        md5_before != md5_after | mtime_before != mtime_after ~ "overwritten",
        .default = NA_character_
      ),
      matches_deposit = if_else(effect == "overwritten", md5_before == md5_after, NA)
    ) |>
    filter(!is.na(effect)) |>
    transmute(pass = pass, file, effect, matches_deposit)

  unlink(scratch, recursive = TRUE)
  list(status = status, touched = touched)
}

runs <- imap(passes, \(files, pass) run_pass(pass, files))

# The two archive tables ----
run_status <- map(runs, "status") |>
  list_rbind() |>
  transmute(
    pass, script,
    role = "analysis",
    exit_status,
    outcome = case_when(
      timed_out ~ "timeout",
      exit_status == 0 ~ "clean",
      .default = "error"
    ),
    stopped_at
  )

overwrites <- map(runs, "touched") |>
  list_rbind() |>
  bind_rows(tibble(pass = character(), file = character(), effect = character(),
                   matches_deposit = logical()))

stopifnot(nrow(run_status) == 2 * length(scripts))

write_csv(run_status, here::here("ground_truth", "archive_run_status.csv"))
write_csv(overwrites, here::here("ground_truth", "archive_overwrites.csv"))

print(run_status |> select(pass, script, outcome), n = nrow(run_status))
print(overwrites)
