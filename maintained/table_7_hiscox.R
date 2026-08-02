# coppock_mcclellan_2019/maintained/table_7_hiscox.R
# Output: output/table_7_hiscox.csv, output/table_7_hiscox.tex
# Depends on: helpers.R, original/ReplicationArchive/HiscoxReplicationStacked.RData
# Description: Hiscox (2006) free-trade framing replication on Lucid, MTurk, GfK/TESS and
#   the original sample, the archive's script 07. The archive README calls this Table 7;
#   the published article prints no such table, and these estimates reach print only in
#   standardized form as the Hiscox facet of Figure 2.

source(here::here("maintained", "helpers.R"))

load(file.path(data_dir, "HiscoxReplicationStacked.RData"))

surveys <- c("lucid", "mturk", "tess", "hiscox")

fits <- map(surveys, function(s) {
  lm_robust(Y_Hiscox ~ Z_Hiscox_expert + Z_Hiscox_valence,
            data = filter(hiscox_stacked, survey == s))
})
names(fits) <- surveys

results <- map_dfr(fits, tidy, .id = "survey") |>
  select(survey, term, estimate, std.error, statistic, p.value, conf.low, conf.high) |>
  left_join(tibble(survey = surveys, nobs = map_int(fits, ~ as.integer(.x$nobs))),
            by = "survey")

write_csv(results, file.path(out_dir, "table_7_hiscox.csv"))

modelsummary(
  fits,
  output = file.path(out_dir, "table_7_hiscox.tex"),
  title = "Hiscox (2006) replications",
  gof_map = c("nobs", "r.squared"),
  stars = TRUE
)
