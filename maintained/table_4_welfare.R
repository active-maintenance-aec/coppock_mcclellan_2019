# coppock_mcclellan_2019/maintained/table_4_welfare.R
# Output: output/table_4_welfare.csv, output/table_4_welfare_ns.csv,
#         output/table_4_welfare.tex
# Depends on: helpers.R, original/ReplicationArchive/WelfareReplicationStacked.RData
# Description: Welfare question-wording replication on Lucid, MTurk, GSS 1984 and GSS 2014,
#   the archive's script 04. The archive README calls this Table 4; the published article
#   prints no such table, and these estimates reach print only in standardized form as
#   the Welfare facet of Figure 2.
#   The archive fits lm() and passes starprep() to stargazer for HC2 standard errors.
#   lm_robust() computes the same HC2 quantities in one step.

source(here::here("maintained", "helpers.R"))

load(file.path(data_dir, "WelfareReplicationStacked.RData"))

surveys <- c("lucid", "mturk", "GSS84", "GSS14")

fits <- map(surveys, function(s) {
  lm_robust(welfare_recode ~ welfare, data = filter(welfare_stacked, survey == s))
})
names(fits) <- surveys

results <- map_dfr(fits, tidy, .id = "survey") |>
  select(survey, term, estimate, std.error, statistic, p.value, conf.low, conf.high) |>
  left_join(tibble(survey = surveys, nobs = map_int(fits, ~ as.integer(.x$nobs))),
            by = "survey")

write_csv(results, file.path(out_dir, "table_4_welfare.csv"))

# Rows in the stacked frame and rows the regression actually uses. The two differ:
# subjects with a missing or "don't know" outcome are dropped from the fit, following
# the original authors, and the appendix's stated sample sizes are the fitted ones.
ns <- tibble(
  survey = surveys,
  rows = map_int(surveys, ~ sum(welfare_stacked$survey == .x, na.rm = TRUE)),
  n = map_int(fits, ~ as.integer(.x$nobs))
)

write_csv(ns, file.path(out_dir, "table_4_welfare_ns.csv"))

modelsummary(
  fits,
  output = file.path(out_dir, "table_4_welfare.tex"),
  title = "Welfare replications",
  gof_map = c("nobs", "r.squared"),
  stars = TRUE
)
