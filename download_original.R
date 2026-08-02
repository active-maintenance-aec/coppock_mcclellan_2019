# coppock_mcclellan_2019/download_original.R
# Output: original/ (the deposited replication archive, not redistributed in this repo)
# Depends on: original_manifest.csv
# Description: Fetch the deposited archive from Harvard Dataverse and verify every file.
#   Run this once before running anything in maintained/. Re-running is free: files
#   already present with the right checksum are not downloaded again.
#
#   The manifest carries two checksums per file. md5_served is the MD5 of the bytes
#   Dataverse returns for `?format=original`, which is what this code was written
#   against. md5_published is the checksum Dataverse displays. Here all 29 agree, but
#   they do not always: another deposit in this program carries three published
#   checksums that verify neither the original nor the derived tabular file, so
#   verification runs against md5_served and any disagreement is reported.
#
#   Eleven of the 29 files were ingested by Dataverse into tabular .tab representations;
#   the served_as column records the name Dataverse gives the derived file.
#   `?format=original` returns the deposited .RData bytes in every case.
#
#   Every file sits under a ReplicationArchive/ directory label in the deposit, so the
#   manifest's file column carries that prefix and the directory is created here.

library(tidyverse)
library(here)

here::i_am("download_original.R")

dataset_doi <- "doi:10.7910/DVN/DDWWJW"
base_url <- "https://dataverse.harvard.edu/api/access/datafile"

# Manifest ----
manifest <- read_csv(here::here("original_manifest.csv"), show_col_types = FALSE)

planned <- manifest |>
  mutate(
    path = here::here("original", file),
    url = str_glue("{base_url}/{dataverse_file_id}?format=original"),
    md5_local = unname(tools::md5sum(path)),
    needs_download = is.na(md5_local) | md5_local != md5_served
  )

walk(unique(dirname(planned$path)), dir.create, recursive = TRUE, showWarnings = FALSE)

# Download what is missing or wrong ----
# format=original asks for the deposited bytes rather than the tabular representation
# Dataverse derives for ingested files.
walk2(
  planned$url[planned$needs_download],
  planned$path[planned$needs_download],
  function(url, path) download.file(url, destfile = path, mode = "wb", quiet = TRUE)
)

print(str_glue("Downloaded {sum(planned$needs_download)} of {nrow(planned)} files; ",
               "{sum(!planned$needs_download)} already present and verified."))

# Verify ----
verified <- planned |>
  mutate(
    md5_downloaded = unname(tools::md5sum(path)),
    match = md5_downloaded == md5_served,
    published_agrees = md5_served == md5_published
  ) |>
  select(file, bytes, md5_served, md5_downloaded, match, published_agrees)

print(verified, n = nrow(verified))

if (!all(verified$match)) {
  stop("Checksum mismatch: the downloaded archive does not match what Dataverse served when this code was written.")
}

# original/ must hold the deposit and nothing else ----
# Verification by checksum alone does not catch a file the deposit never contained, and
# running an archive in place both overwrites deposited files and leaves new ones behind.
# Nothing in maintained/ writes to original/, so anything unlisted here arrived by some
# other route and the archive can no longer be trusted to be the deposited one.
strays <- setdiff(
  list.files(here::here("original"), recursive = TRUE, all.files = TRUE, no.. = TRUE),
  manifest$file
)

if (length(strays) > 0) {
  stop(str_glue("original/ holds {length(strays)} file(s) the manifest does not list: ",
                "{str_flatten_comma(strays)}. Move them elsewhere before running again."))
}

print(str_glue("All {nrow(verified)} files match md5_served and original/ holds nothing else. ",
               "{sum(!verified$published_agrees)} carry a published checksum that disagrees."))
print(str_glue("Archive: {dataset_doi}"))
