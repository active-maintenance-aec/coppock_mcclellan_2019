# coppock_mcclellan_2019/maintained/appendix_table_1_rounding_sampler.R
# Output: output/appendix_table_1_rounding_sampler.csv,
#         output/appendix_table_1_rounding_headline.csv
# Depends on: helpers.R, original/ReplicationArchive/standardized_stacked_st.rds
# Description: Re-run the deposit's bootstrap under the random number generator of its day.
#   The archive was deposited in December 2018. R 3.6.0, released in April 2019, changed
#   how sample() maps the uniform stream onto integers, and rsample::bootstraps() draws
#   its resamples through sample.int(), so this deposit is one whose stochastic output
#   was produced under a sampler no current R installation uses by default.
#
#   Asking whether that matters is a question about the archive rather than about the
#   maintained rewrite, so it gets its own script and its own output. The rewrite keeps
#   the current sampler, which is the correct one.
#
#   This runs the same 200-seed procedure as appendix_table_1_bootstrap_stability.R under
#   RNGkind(sample.kind = "Rounding"), so the two output files are directly comparable.
#   The sampler is restored explicitly rather than through on.exit(), which does not
#   reliably fire at the top level of a sourced file, and the restoration is asserted so
#   that nothing sourced after this script by run_all.R can inherit the old generator.

source(here::here("maintained", "helpers.R"))

standardized_stacked_st <- read_rds(file.path(data_dir, "standardized_stacked_st.rds"))

est <- compute_distances(standardized_stacked_st)

sampler_before <- RNGkind()[3]
suppressWarnings(RNGkind(sample.kind = "Rounding"))

passes <- map_dfr(1:200, bootstrap_distance_ses,
                  df = standardized_stacked_st, times = 100) |>
  left_join(est, by = "variable") |>
  filter(!is.na(se)) |>
  mutate(z = lucid_is_closer / se,
         p_archive = pnorm(2 * (1 - abs(z))),
         p_twotail = 2 * pnorm(-abs(z)))

RNGkind(sample.kind = sampler_before)
stopifnot(RNGkind()[3] == sampler_before)

rounding <- passes |>
  group_by(variable) |>
  summarize(
    lucid_is_closer = first(lucid_is_closer),
    se_mean = mean(se),
    se_q025 = quantile(se, 0.025),
    se_q975 = quantile(se, 0.975),
    share_sig_archive = mean(p_archive < 0.05),
    .groups = "drop"
  )

write_csv(rounding, file.path(out_dir, "appendix_table_1_rounding_sampler.csv"))

headline <- passes |>
  group_by(seed) |>
  summarize(n_sig_closer_archive = sum(lucid_is_closer > 0 & p_archive < 0.05),
            .groups = "drop") |>
  summarize(
    passes = n(),
    share_archive_equals_14 = mean(n_sig_closer_archive == 14),
    archive_min = min(n_sig_closer_archive),
    archive_max = max(n_sig_closer_archive)
  ) |>
  mutate(sampler = "Rounding")

write_csv(headline, file.path(out_dir, "appendix_table_1_rounding_headline.csv"))
print(headline)
