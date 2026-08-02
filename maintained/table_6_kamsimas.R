# coppock_mcclellan_2019/maintained/table_6_kamsimas.R
# Output: output/table_6_kamsimas.csv, output/table_6_kamsimas.tex
# Depends on: helpers.R, original/ReplicationArchive/KamSimasReplicationStacked.RData
# Description: Kam and Simas (2010) risk-acceptance by mortality-frame replication, the
#   archive's script 06 (its OLS half). The archive README calls this Table 6; the
#   published article prints no such table, and these estimates reach print only in
#   standardized form as the Kam and Simas facet of Figure 2. The probit half of script
#   06 is appendix_table_2_kamsimas_probit.R, and that one is published.
#   The covariate-adjusted Lucid and MTurk models carry a missing_covs indicator that
#   the original Kam and Simas model does not, because only the replications imputed
#   missing covariates. That asymmetry is the archive's and is preserved.

source(here::here("maintained", "helpers.R"))

load(file.path(data_dir, "KamSimasReplicationStacked.RData"))

fml_base <- pfp1 ~ mortalityfirst + ramean
fml_ctrl_replication <- pfp1 ~ mortalityfirst + ramean + female_imp + age01_imp +
  education01_7_imp + income01_imp + ideology01_imp + missing_covs
fml_ctrl_original <- pfp1 ~ mortalityfirst + ramean + female_imp + age01_imp +
  education01_7_imp + income01_imp + ideology01_imp
fml_interaction <- pfp1 ~ mortalityfirst * ramean

model_specs <- tribble(
  ~label, ~sample, ~fml,
  "lucid_base", "lucid", fml_base,
  "lucid_ctrl", "lucid", fml_ctrl_replication,
  "lucid_int", "lucid", fml_interaction,
  "mturk_base", "mturk_risk", fml_base,
  "mturk_ctrl", "mturk_risk", fml_ctrl_replication,
  "mturk_int", "mturk_risk", fml_interaction,
  "kam_base", "kam", fml_base,
  "kam_ctrl", "kam", fml_ctrl_original,
  "kam_int", "kam", fml_interaction
)

fits <- map2(model_specs$fml, model_specs$sample, function(fml, s) {
  lm_robust(fml, data = filter(kam_stacked, survey == s))
})
names(fits) <- model_specs$label

results <- map_dfr(fits, tidy, .id = "model") |>
  select(model, term, estimate, std.error, statistic, p.value, conf.low, conf.high) |>
  left_join(tibble(model = model_specs$label, nobs = map_int(fits, ~ as.integer(.x$nobs))),
            by = "model")

write_csv(results, file.path(out_dir, "table_6_kamsimas.csv"))

modelsummary(
  fits,
  output = file.path(out_dir, "table_6_kamsimas.tex"),
  title = "Kam and Simas (2010) replication, OLS",
  coef_omit = "female_imp|age01_imp|education01_7_imp|income01_imp|ideology01_imp|missing_covs",
  gof_map = c("nobs", "r.squared"),
  stars = TRUE
)
