# coppock_mcclellan_2019/maintained/appendix_table_1_distance_tests.R
# Output: output/appendix_table_1_distance_tests.csv,
#         output/appendix_table_1_distance_counts.csv
# Depends on: helpers.R, original/ReplicationArchive/standardized_stacked_st.rds
# Description: Online appendix Table 1, formal tests of demographic differences by sample,
#   the archive's script 12. For each standardized variable this is
#   |MTurk - ANES2012| - |Lucid - ANES2012|, positive when Lucid sits closer to the 2012
#   ANES benchmark, with a nonparametric bootstrap standard error.
#
#   Two p-values are reported. p_archive is the archive's own expression,
#   pnorm(2 * (1 - |z|)), which is what produced the p-value column of the published
#   table. p_twotail is 2 * pnorm(-|z|), the two-tailed normal approximation the appendix
#   text says was used. They differ: p_archive calls a difference significant at the
#   0.05 level once |z| exceeds 1.82 rather than 1.96, so it is the more liberal of the
#   two. The counts file records what each implies. See the errata section of the report.
#
#   The archive sets no seed, so its counts move from run to run. One is set here.
#   race_asian and race_native drop out because MTurk recorded no respondents in either
#   category, leaving the difference undefined; the published table omits them too, and
#   its 21 rows are what remains.

source(here::here("maintained", "helpers.R"))

seed <- 20260321

standardized_stacked_st <- read_rds(file.path(data_dir, "standardized_stacked_st.rds"))

est <- compute_distances(standardized_stacked_st)

boot_ses <- bootstrap_distance_ses(seed, standardized_stacked_st, times = 100) |>
  select(variable, se)

# The archive assigns display names positionally, which is safe only as long as the
# row order of the join never changes. A named lookup does the same job by key.
varnames <- c(
  female = "Female",
  education = "Education",
  age = "Age",
  income = "Mean income",
  race_white = "White",
  race_black = "Black",
  race_hispanic = "Hispanic",
  race_asian = "Asian",
  race_native = "Native American",
  region_northeast = "Northeast",
  region_midwest = "Midwest",
  region_south = "South",
  region_west = "West",
  register = "Voter registration",
  vote = "Voter turnout",
  party7 = "Party ID",
  ideology = "Ideology",
  interest = "Political Interest",
  extraversion = "Extraverted",
  agreeableness = "Agreeable",
  conscientiousness = "Conscientious",
  emotionalstability = "Stable",
  opennesstoexperiences = "Open"
)

distance_table <- left_join(est, boot_ses, by = "variable") |>
  filter(variable != "weights", !is.na(se)) |>
  mutate(
    varname = unname(varnames[variable]),
    z = lucid_is_closer / se,
    p_archive = pnorm(2 * (1 - abs(z))),
    p_twotail = 2 * pnorm(-abs(z))
  ) |>
  select(variable, varname, lucid_is_closer, se, z, p_archive, p_twotail)

write_csv(distance_table, file.path(out_dir, "appendix_table_1_distance_tests.csv"))

counts <- distance_table |>
  summarize(
    n_variables = n(),
    n_lucid_closer = sum(lucid_is_closer > 0),
    n_mturk_closer = sum(lucid_is_closer < 0),
    n_sig_closer_archive = sum(lucid_is_closer > 0 & p_archive < 0.05),
    n_sig_farther_archive = sum(lucid_is_closer < 0 & p_archive < 0.05),
    n_sig_closer_twotail = sum(lucid_is_closer > 0 & p_twotail < 0.05),
    n_sig_farther_twotail = sum(lucid_is_closer < 0 & p_twotail < 0.05)
  )

write_csv(counts, file.path(out_dir, "appendix_table_1_distance_counts.csv"))
print(counts)
