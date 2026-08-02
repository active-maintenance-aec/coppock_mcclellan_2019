# coppock_mcclellan_2019/maintained/table_5_asian_disease.R
# Output: output/table_5_asian_disease.csv, output/table_5_asian_disease.tex
# Depends on: helpers.R, original/ReplicationArchive/AsianDiseaseStacked.RData
# Description: Asian Disease framing replication (Tversky and Kahneman 1981) on Lucid,
#   MTurk and the original classroom sample, the archive's script 05. The archive README
#   calls this Table 5; the published article prints no such table, and these estimates
#   reach print only in standardized form as the Asian Disease facet of Figure 2.

source(here::here("maintained", "helpers.R"))

load(file.path(data_dir, "AsianDiseaseStacked.RData"))

surveys <- c("lucid", "mturk", "original")

fits <- map(surveys, function(s) {
  lm_robust(pfp ~ mortality_frame, data = filter(ad_stacked, survey == s))
})
names(fits) <- surveys

results <- map_dfr(fits, tidy, .id = "survey") |>
  select(survey, term, estimate, std.error, statistic, p.value, conf.low, conf.high) |>
  left_join(tibble(survey = surveys, nobs = map_int(fits, ~ as.integer(.x$nobs))),
            by = "survey")

write_csv(results, file.path(out_dir, "table_5_asian_disease.csv"))

modelsummary(
  fits,
  output = file.path(out_dir, "table_5_asian_disease.tex"),
  title = "Asian Disease replications",
  gof_map = c("nobs", "r.squared"),
  stars = TRUE
)
