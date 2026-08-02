# coppock_mcclellan_2019/maintained/table_8_health_rumors.R
# Output: output/table_8_health_rumors.csv, output/table_8_health_rumors.tex
# Depends on: helpers.R, original/ReplicationArchive/HealthRumorsReplicationStacked.RData
# Description: Berinsky (2017) death-panel rumor correction replication, the archive's
#   script 08. The archive README calls this Table 8; the published article prints no
#   such table, and these estimates reach print only in standardized form as the Berinsky
#   facet of Figure 2.
#   The original sample is stacked under survey == "ssi". The article describes it as a
#   Survey Sampling International sample; the online appendix section 2.5.1 calls it
#   1,593 MTurk respondents. The data object agrees with the article.

source(here::here("maintained", "helpers.R"))

load(file.path(data_dir, "HealthRumorsReplicationStacked.RData"))

surveys <- c("lucid", "ssi")

fits <- map(surveys, function(s) {
  lm_robust(Y_deathpanel ~ Z_health_rumor, data = filter(rumor_stacked, survey == s))
})
names(fits) <- surveys

results <- map_dfr(fits, tidy, .id = "survey") |>
  select(survey, term, estimate, std.error, statistic, p.value, conf.low, conf.high) |>
  left_join(tibble(survey = surveys, nobs = map_int(fits, ~ as.integer(.x$nobs))),
            by = "survey")

write_csv(results, file.path(out_dir, "table_8_health_rumors.csv"))

modelsummary(
  fits,
  output = file.path(out_dir, "table_8_health_rumors.tex"),
  title = "Berinsky (2017) replication",
  gof_map = c("nobs", "r.squared"),
  stars = TRUE
)
