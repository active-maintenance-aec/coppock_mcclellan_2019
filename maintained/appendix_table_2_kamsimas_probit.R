# coppock_mcclellan_2019/maintained/appendix_table_2_kamsimas_probit.R
# Output: output/appendix_table_2_kamsimas_probit.csv,
#         output/appendix_table_2_kamsimas_probit.tex
# Depends on: helpers.R, original/ReplicationArchive/KamSimasReplicationStacked.RData
# Description: Online appendix Table 2, Kam and Simas (2010) replication under probit,
#   the probit half of the archive's script 06. This is one of only two tables the
#   published paper actually prints.
#
#   The published table's note says "Robust standard errors are in parentheses," and its
#   numbers are HC2 sandwich standard errors. The archive's probit stargazer call passes
#   no se = starprep(...) argument, unlike every OLS call in the same script, so as
#   deposited it would print model-based probit standard errors instead. Both columns are
#   written out here: robust.std.error reproduces the published table, std.error is what
#   the deposited script would print.
#
#   Unlike the OLS models in table_6_kamsimas.R, the covariate-adjusted probit models
#   carry no missing_covs indicator for any sample. That is the archive's specification.

source(here::here("maintained", "helpers.R"))

load(file.path(data_dir, "KamSimasReplicationStacked.RData"))

fml_base <- pfp1 ~ mortalityfirst + ramean
fml_ctrl <- pfp1 ~ mortalityfirst + ramean + female_imp + age01_imp +
  education01_7_imp + income01_imp + ideology01_imp
fml_interaction <- pfp1 ~ mortalityfirst * ramean

model_specs <- tribble(
  ~label, ~sample, ~fml,
  "lucid_base", "lucid", fml_base,
  "lucid_ctrl", "lucid", fml_ctrl,
  "lucid_int", "lucid", fml_interaction,
  "mturk_base", "mturk_risk", fml_base,
  "mturk_ctrl", "mturk_risk", fml_ctrl,
  "mturk_int", "mturk_risk", fml_interaction,
  "kam_base", "kam", fml_base,
  "kam_ctrl", "kam", fml_ctrl,
  "kam_int", "kam", fml_interaction
)

fits <- map2(model_specs$fml, model_specs$sample, function(fml, s) {
  glm(fml, family = binomial(link = "probit"), data = filter(kam_stacked, survey == s))
})
names(fits) <- model_specs$label

vcovs <- map(fits, sandwich::vcovHC, type = "HC2")

robust_ses <- map_dfr(vcovs, function(vc) {
  tibble(term = rownames(vc), robust.std.error = sqrt(diag(vc)))
}, .id = "model")

results <- map_dfr(fits, tidy, .id = "model") |>
  left_join(robust_ses, by = c("model", "term")) |>
  select(model, term, estimate, robust.std.error, std.error, statistic, p.value)

fit_stats <- map_dfr(fits, function(fit) {
  tibble(nobs = stats::nobs(fit), logLik = as.numeric(stats::logLik(fit)),
         AIC = stats::AIC(fit))
}, .id = "model")

write_csv(left_join(results, fit_stats, by = "model"),
          file.path(out_dir, "appendix_table_2_kamsimas_probit.csv"))

modelsummary(
  fits,
  vcov = vcovs,
  output = file.path(out_dir, "appendix_table_2_kamsimas_probit.tex"),
  title = "Kam and Simas (2010) replication, probit specifications",
  coef_omit = "female_imp|age01_imp|education01_7_imp|income01_imp|ideology01_imp",
  gof_map = c("nobs", "logLik", "aic"),
  stars = TRUE
)
