# coppock_mcclellan_2019/maintained/appendix_table_1_bootstrap_stability.R
# Output: output/appendix_table_1_bootstrap_stability.csv
# Depends on: helpers.R, original/ReplicationArchive/standardized_stacked_st.rds
# Description: How much of appendix Table 1 is Monte Carlo noise.
#   The archive estimates the standard errors in appendix Table 1 from 100 bootstrap
#   resamples and sets no seed, so the standard errors, and the p-values computed from
#   them, are different every time the script is run. The point estimates are not:
#   they involve no resampling.
#
#   This script runs the archive's whole 100-resample procedure 200 times over 200 seeds
#   and records, for each variable, the distribution of the standard error and of the
#   two p-values. Whether a published standard error reproduces is then a question about
#   that distribution rather than about one draw. It also records how often the whole
#   table's headline counts come out at the published 18 closer and 14 significant.
#
#   Cost: about four minutes. One 100-resample pass takes 1.2 seconds on the machine
#   this was written on, and this runs 200 of them.

source(here::here("maintained", "helpers.R"))

standardized_stacked_st <- read_rds(file.path(data_dir, "standardized_stacked_st.rds"))

est <- compute_distances(standardized_stacked_st)

passes <- map_dfr(1:200, bootstrap_distance_ses,
                  df = standardized_stacked_st, times = 100) |>
  left_join(est, by = "variable") |>
  filter(!is.na(se)) |>
  mutate(z = lucid_is_closer / se,
         p_archive = pnorm(2 * (1 - abs(z))),
         p_twotail = 2 * pnorm(-abs(z)))

stability <- passes |>
  group_by(variable) |>
  summarize(
    lucid_is_closer = first(lucid_is_closer),
    se_mean = mean(se),
    se_q025 = quantile(se, 0.025),
    se_q975 = quantile(se, 0.975),
    p_archive_q025 = quantile(p_archive, 0.025),
    p_archive_q975 = quantile(p_archive, 0.975),
    share_sig_archive = mean(p_archive < 0.05),
    share_sig_twotail = mean(p_twotail < 0.05),
    .groups = "drop"
  )

write_csv(stability, file.path(out_dir, "appendix_table_1_bootstrap_stability.csv"))

headline <- passes |>
  group_by(seed) |>
  summarize(
    n_sig_closer_archive = sum(lucid_is_closer > 0 & p_archive < 0.05),
    n_sig_closer_twotail = sum(lucid_is_closer > 0 & p_twotail < 0.05),
    .groups = "drop"
  ) |>
  summarize(
    passes = n(),
    share_archive_equals_14 = mean(n_sig_closer_archive == 14),
    archive_min = min(n_sig_closer_archive),
    archive_max = max(n_sig_closer_archive),
    share_twotail_equals_14 = mean(n_sig_closer_twotail == 14),
    twotail_min = min(n_sig_closer_twotail),
    twotail_max = max(n_sig_closer_twotail)
  )

write_csv(headline, file.path(out_dir, "appendix_table_1_bootstrap_headline.csv"))
print(headline)
