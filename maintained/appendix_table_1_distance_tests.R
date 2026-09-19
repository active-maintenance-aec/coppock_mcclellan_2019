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
#   THE RESAMPLE COUNT IS 125,000 AND THE SEED IS DECLARED, and neither is the archive's.
#   The archive draws 100 resamples and sets no seed, so every standard error it prints,
#   and every count computed from them, moves from run to run: appendix_table_1_bootstrap_
#   stability.R runs that procedure over 200 seeds and reaches the published 14 significant
#   differences on 39.5 per cent of them, ranging 12 to 15. A seed alone fixes the numbers
#   without settling them, because the sampling error of a bootstrap SD is about
#   SE / sqrt(2B): at B = 100 that is 0.0035 on a standard error near 0.05, and at B = 2,000
#   it is still 0.0008, most of the third decimal the appendix prints. Measured over seeds
#   343, 344 and 345, B = 2,000 reproduces its own third decimal on 2 of the 21 rows and
#   B = 125,000 on 18 of them. The three that still move at 125,000 are the three sitting
#   closest to a .0005 rounding boundary, 0.00004, 0.00004 and 0.00015 away, where no
#   finite number of resamples settles the digit; every row's spread across the three seeds
#   is under 0.0005. That measurement is a one-off and is not repeated by the pipeline,
#   which would cost an hour to say again what SE / sqrt(2B) says for nothing: errata.qmd
#   derives the implied sampling error from `se` and `n_resamples` below. B = 125,000 costs
#   about 18 minutes.
#
#   The two stability scripts keep the archive's 100 and vary the seed on purpose: they
#   measure what the deposited procedure does, and raising their B would measure something
#   else.
#   race_asian and race_native drop out because MTurk recorded no respondents in either
#   category, leaving the difference undefined; the published table omits them too, and
#   its 21 rows are what remains.

source(here::here("maintained", "helpers.R"))

seed <- 343
n_resamples <- 125000

standardized_stacked_st <- read_rds(file.path(data_dir, "standardized_stacked_st.rds"))

est <- compute_distances(standardized_stacked_st)

boot_ses <- bootstrap_distance_ses(seed, standardized_stacked_st, times = n_resamples) |>
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

# THE SEED AND THE RESAMPLE COUNT ARE OUTPUTS, not something a reader of the report or of
# the errata note types again. Both documents say what this bootstrap was, and a number
# stated in two places is a number that can disagree with itself.
counts <- distance_table |>
  summarize(
    n_resamples = n_resamples,
    seed = seed,
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
