# coppock_mcclellan_2019/run_all.R
# Runs the whole reproduction in order: fetch and verify the deposited archive, then
# every table and figure, then the in-text numbers. Every script is self-contained and
# can also be run on its own.

library(here)
here::i_am("run_all.R")

# Deposited archive ----
# Downloads from Dataverse on a fresh clone; verifies checksums either way.
source(here::here("download_original.R"))

# Descriptive tables ----
source(here::here("maintained", "table_1_demographics.R"))
source(here::here("maintained", "table_2_political.R"))
source(here::here("maintained", "table_3_psychological.R"))
source(here::here("maintained", "table_9_survey_behavior.R"))

# Experimental replications ----
source(here::here("maintained", "table_4_welfare.R"))
source(here::here("maintained", "table_5_asian_disease.R"))
source(here::here("maintained", "table_6_kamsimas.R"))
source(here::here("maintained", "table_7_hiscox.R"))
source(here::here("maintained", "table_8_health_rumors.R"))

# Figures ----
source(here::here("maintained", "figure_1_standardized_demos.R"))
source(here::here("maintained", "figure_2_standardized_experiments.R"))
source(here::here("maintained", "figures_3_4_5_heterogeneous_effects.R"))

# Appendix tables ----
# The distance tests bootstrap 100 times, a few seconds.
source(here::here("maintained", "appendix_table_1_distance_tests.R"))
source(here::here("maintained", "appendix_table_2_kamsimas_probit.R"))

# Bootstrap stability ----
# The deposit's bootstrap sets no seed, so these two measure how much of appendix
# Table 1 is Monte Carlo noise, once under the current sampler and once under the one
# in force when the archive was deposited. Each repeats the deposit's whole 100-resample
# procedure 200 times and takes about four minutes.
source(here::here("maintained", "appendix_table_1_bootstrap_stability.R"))
source(here::here("maintained", "appendix_table_1_rounding_sampler.R"))

# In-text numbers ----
# Both read the table and figure outputs above, so they run after them.
source(here::here("maintained", "text_in_text_claims.R"))
source(here::here("maintained", "text_descriptive_claims.R"))

# Figure timestamps ----
# R's pdf() device stamps a wall-clock /CreationDate and /ModDate into every figure it
# writes, and those two fields are the only reason two runs of this pipeline produce
# differing files. Blanking them lets the determinism check cover every file the
# pipeline writes rather than all but the figures.
source(here::here("maintained", "helpers.R"))
walk(
  list.files(here::here("maintained", "output"), pattern = "\\.pdf$", full.names = TRUE),
  blank_pdf_timestamps
)

# Ground truth ----
# Reads maintained/output/ only, so it runs after everything that writes there. It also
# runs maintained/in_text_claims.R under capture.output, counts the claims that file
# printed against the extraction, and compares the two instruments value by value.
source(here::here("ground_truth", "build_ground_truth.R"))

# In-text claims, for a reader ----
# The gate above ran this file and read only what it printed. Running it again here is
# what puts the claims beside their sentences in the console log.
source(here::here("maintained", "in_text_claims.R"))

# Deposited archive, again ----
# The check at the top of this file is a precondition: it says original/ was intact
# before anything ran. Nothing above writes to original/, and this second pass is what
# demonstrates it rather than assuming it. Nothing is downloaded; the files are already
# present and are re-checked against the manifest on checksum, byte size and membership.
source(here::here("download_original.R"))
