# coppock_mcclellan_2019/ground_truth/build_ground_truth.R
# Output: ground_truth/coppock_mcclellan_2019_ground_truth.csv
# Depends on: maintained/output/ (run run_all.R first)
# Description: Assemble the ground truth table.
#
#   Every value in value_paper was read off the published article or the published online
#   appendix and is used only as a comparison target. Where the paper does not state a
#   quantity the cell is blank and the match columns are empty, which is the case for
#   all five figures: they print no numbers.
#
#   value_script and value_rewrite are read back out of maintained/output/ rather than
#   typed, so this table cannot drift from the pipeline. value_script is what the
#   deposited code computes and value_rewrite is what the maintained code computes; they
#   differ only where the deposit and the published table disagree about what was run.
#
#   defect_locus is set on every row where the maintained rewrite does not match the
#   published value, and says where the disagreement lives: paper_internal, archive,
#   environment, rewrite or unresolved.
#
#   claim_id keys each row to ground_truth/published_claims.csv, the extraction of every
#   quantity the article and its appendix state. That key is what makes coverage
#   checkable in both directions and what lets this file be compared, value by value,
#   against maintained/in_text_claims.R, which reaches the same numbers out of the same
#   pipeline outputs by its own path. The gates at the foot of this file do both.

library(here)
library(tidyverse)

here::i_am("ground_truth/build_ground_truth.R")

options(width = 200)

out <- function(f) read_csv(here::here("maintained", "output", f), show_col_types = FALSE)

# value_paper is the string the article prints, and a type guess would destroy it: a
# column that looks numeric is read as a double, which cannot tell 0.020 from 0.02.
published_claims <- read_csv(
  here::here("ground_truth", "published_claims.csv"),
  col_types = cols(.default = col_character())
) |>
  mutate(needs_block = needs_block == "TRUE")

distances <- out("appendix_table_1_distance_tests.csv")
stability <- out("appendix_table_1_bootstrap_stability.csv")
probit <- out("appendix_table_2_kamsimas_probit.csv")
welfare_ns <- out("table_4_welfare_ns.csv")
asian_disease <- out("table_5_asian_disease.csv")
kamsimas <- out("table_6_kamsimas.csv")
hiscox <- out("table_7_hiscox.csv")
rumors <- out("table_8_health_rumors.csv")
text_claims <- out("text_in_text_claims.csv")

figure_files <- c(
  "Figure 1" = "figure_1_standardized_demos.csv",
  "Figure 2" = "figure_2_standardized_experiments.csv",
  "Figure 3" = "figure_3_cate_welfare_ad_ks.csv",
  "Figure 4" = "figure_4_cate_hiscox.csv",
  "Figure 5" = "figure_5_cate_berinsky.csv"
)

# Appendix Table 1 ----
# Transcribed from the online appendix, section 1, "Formal Tests of Demographic
# Differences by Sample". The table's 21 rows, in the order it prints them.
#
# The published columns carry a _paper suffix because the pipeline outputs joined to
# them below have columns of their own called se and p. Left unsuffixed, dplyr resolves
# the collision into se.x and se.y, and a transmute that reaches for the wrong one
# silently files the pipeline's own number as the published value. Naming the published
# columns for what they are makes that mistake unavailable.
paper_appendix_1 <- tribble(
  ~variable,               ~distance_paper, ~se_paper, ~p_paper,
  "female",                    0.159, 0.049, 0.000,
  "education",                 0.285, 0.041, 0.000,
  "age",                       0.708, 0.032, 0.000,
  "income",                    0.099, 0.033, 0.000,
  "race_white",                0.018, 0.041, 0.873,
  "race_black",                0.152, 0.033, 0.000,
  "race_hispanic",            -0.042, 0.035, 0.357,
  "region_northeast",          0.079, 0.054, 0.179,
  "region_midwest",            0.052, 0.046, 0.409,
  "region_south",              0.137, 0.064, 0.010,
  "region_west",              -0.007, 0.039, 0.948,
  "register",                  0.076, 0.050, 0.157,
  "vote",                     -0.124, 0.044, 0.000,
  "party7",                    0.117, 0.055, 0.010,
  "ideology",                  0.465, 0.069, 0.000,
  "interest",                  0.540, 0.082, 0.000,
  "extraversion",              0.100, 0.052, 0.034,
  "agreeableness",             0.203, 0.077, 0.001,
  "conscientiousness",         0.420, 0.065, 0.000,
  "emotionalstability",        0.248, 0.054, 0.000,
  "opennesstoexperiences",     0.157, 0.069, 0.005
)

# The point estimates involve no resampling and are the same number every run. The
# deposited script and the rewrite compute them identically.
a1_distance <- paper_appendix_1 |>
  left_join(distances, by = "variable") |>
  transmute(
    claim_id = paste0("a1_distance_", variable),
    table_figure = "Appendix Table 1",
    claim = paste0("Distance, ", varname),
    value_script = round(lucid_is_closer, 3),
    value_paper = distance_paper,
    value_rewrite = round(lucid_is_closer, 3),
    digits = 3,
    notes = "|MTurk - ANES 2012| - |Lucid - ANES 2012| in standardized units. Deterministic: no resampling enters the point estimate"
  )

# The standard errors and the p-values computed from them come from 100 bootstrap
# resamples drawn without a seed, so a published value is compared against the sampling
# distribution of the estimator rather than against one draw. The interval is the 95 per
# cent range of the deposit's own 100-resample procedure over 200 independent runs.
a1_se <- paper_appendix_1 |>
  left_join(distances, by = "variable") |>
  left_join(stability, by = "variable") |>
  transmute(
    claim_id = paste0("a1_se_", variable),
    table_figure = "Appendix Table 1",
    claim = paste0("Bootstrap SE, ", varname),
    value_script = round(se, 3),
    value_paper = se_paper,
    value_rewrite = round(se, 3),
    digits = 3,
    in_interval = if_else(se_paper >= se_q025 & se_paper <= se_q975, 1, 0),
    notes = str_glue("Bootstrap SE from 100 resamples. The deposit sets no seed; over 200 runs of its procedure the SE falls in [{sprintf('%.3f', se_q025)}, {sprintf('%.3f', se_q975)}]")
  )

a1_p <- paper_appendix_1 |>
  left_join(distances, by = "variable") |>
  left_join(stability, by = "variable") |>
  transmute(
    claim_id = paste0("a1_p_", variable),
    table_figure = "Appendix Table 1",
    claim = paste0("p-value, ", varname),
    value_script = round(p_archive, 3),
    value_paper = p_paper,
    value_rewrite = round(p_archive, 3),
    digits = 3,
    in_interval = if_else(p_paper >= p_archive_q025 - 5e-4 &
                            p_paper <= p_archive_q975 + 5e-4, 1, 0),
    notes = str_glue("The published column is pnorm(2 * (1 - |z|)), the deposit's expression, not the two-tailed test the appendix describes. Over 200 runs it falls in [{sprintf('%.3f', p_archive_q025)}, {sprintf('%.3f', p_archive_q975)}]")
  )

# The two-tailed p-value the appendix says it used. Not published, so no comparison.
a1_p_twotail <- distances |>
  filter(variable %in% paper_appendix_1$variable) |>
  transmute(
    claim_id = NA_character_,
    table_figure = "Appendix Table 1",
    claim = paste0("Two-tailed p-value, ", varname),
    value_script = NA_real_,
    value_paper = NA_real_,
    value_rewrite = round(p_twotail, 3),
    digits = NA_real_,
    notes = "2 * pnorm(-|z|), the test the appendix text describes. The published table does not use it and does not print it; added by the rewrite"
  )

# Appendix Table 2 ----
# Transcribed from the online appendix, section 2.3.4, read off a rendered page rather
# than from extracted text: the table is nine columns wide and a row read one column out
# of register would manufacture a mismatch.
paper_appendix_2 <- tribble(
  ~model,        ~term,                     ~coef,     ~se,   ~nobs, ~loglik,     ~aic,
  "lucid_base",  "mortalityfirst",           0.898,   0.065,  1629, -1027.212, 2060.424,
  "lucid_ctrl",  "mortalityfirst",           0.898,   0.065,  1629, -1015.762, 2047.524,
  "lucid_int",   "mortalityfirst",           1.155,   0.203,  1629, -1026.356, 2060.713,
  "mturk_base",  "mortalityfirst",           1.182,   0.097,   766,  -448.046,  902.092,
  "mturk_ctrl",  "mortalityfirst",           1.184,   0.098,   766,  -447.878,  911.755,
  "mturk_int",   "mortalityfirst",           1.370,   0.310,   766,  -447.823,  903.646,
  "kam_base",    "mortalityfirst",           1.068,   0.098,   752,  -453.196,  912.392,
  "kam_ctrl",    "mortalityfirst",           1.091,   0.100,   752,  -450.863,  917.727,
  "kam_int",     "mortalityfirst",           1.059,   0.294,   752,  -453.195,  914.391,
  "lucid_base",  "ramean",                   0.253,   0.196,    NA,        NA,       NA,
  "lucid_ctrl",  "ramean",                   0.516,   0.205,    NA,        NA,       NA,
  "lucid_int",   "ramean",                   0.522,   0.269,    NA,        NA,       NA,
  "mturk_base",  "ramean",                   0.906,   0.283,    NA,        NA,       NA,
  "mturk_ctrl",  "ramean",                   0.953,   0.293,    NA,        NA,       NA,
  "mturk_int",   "ramean",                   1.090,   0.412,    NA,        NA,       NA,
  "kam_base",    "ramean",                   0.520,   0.303,    NA,        NA,       NA,
  "kam_ctrl",    "ramean",                   0.587,   0.325,    NA,        NA,       NA,
  "kam_int",     "ramean",                   0.506,   0.485,    NA,        NA,       NA,
  "lucid_int",   "mortalityfirst:ramean",   -0.523,   0.393,    NA,        NA,       NA,
  "mturk_int",   "mortalityfirst:ramean",   -0.368,   0.569,    NA,        NA,       NA,
  "kam_int",     "mortalityfirst:ramean",    0.022,   0.621,    NA,        NA,       NA,
  "lucid_base",  "(Intercept)",             -0.634,   0.106,    NA,        NA,       NA,
  "lucid_ctrl",  "(Intercept)",             -1.040,   0.176,    NA,        NA,       NA,
  "lucid_int",   "(Intercept)",             -0.767,   0.141,    NA,        NA,       NA,
  "mturk_base",  "(Intercept)",             -1.128,   0.163,    NA,        NA,       NA,
  "mturk_ctrl",  "(Intercept)",             -1.193,   0.281,    NA,        NA,       NA,
  "mturk_int",   "(Intercept)",             -1.225,   0.229,    NA,        NA,       NA,
  "kam_base",    "(Intercept)",             -0.705,   0.154,    NA,        NA,       NA,
  "kam_ctrl",    "(Intercept)",             -0.814,   0.275,    NA,        NA,       NA,
  "kam_int",     "(Intercept)",             -0.700,   0.229,    NA,        NA,       NA
)

term_key <- c("mortalityfirst" = "mf", "ramean" = "ra",
              "mortalityfirst:ramean" = "raxmf", "(Intercept)" = "int")

probit_joined <- paper_appendix_2 |>
  left_join(probit, by = c("model", "term"), suffix = c("_paper", "_rewrite")) |>
  mutate(term_id = unname(term_key[term]))

a2_coef <- probit_joined |>
  transmute(
    claim_id = paste0("a2_coef_", model, "_", term_id),
    table_figure = "Appendix Table 2",
    claim = paste0("Coefficient, ", model, ", ", term),
    value_script = round(estimate, 3),
    value_paper = coef,
    value_rewrite = round(estimate, 3),
    digits = 3,
    notes = "Probit coefficient. The deposited script and the rewrite agree exactly"
  )

# The published table's note says "Robust standard errors are in parentheses" and the
# article says all standard errors are HC2. The deposited probit call passes no se =
# argument, unlike every OLS call in the same script, so the deposit would print the
# model-based standard error recorded in value_script.
a2_se <- probit_joined |>
  transmute(
    claim_id = paste0("a2_se_", model, "_", term_id),
    table_figure = "Appendix Table 2",
    claim = paste0("SE, ", model, ", ", term),
    value_script = round(std.error, 3),
    value_paper = se,
    value_rewrite = round(robust.std.error, 3),
    digits = 3,
    notes = "Published SE is HC2 robust, matching the table's own note. The deposited script passes no se = argument and would print the model-based SE in value_script"
  )

a2_fit <- probit_joined |>
  filter(!is.na(nobs_paper)) |>
  transmute(
    model,
    `N` = nobs_paper, `Log likelihood` = loglik, `AIC` = aic,
    n_out = nobs_rewrite, ll_out = round(logLik, 3), aic_out = round(AIC, 3)
  ) |>
  pivot_longer(c(`N`, `Log likelihood`, `AIC`),
               names_to = "quantity", values_to = "value_paper") |>
  mutate(
    value_rewrite = case_when(
      quantity == "N" ~ n_out,
      quantity == "Log likelihood" ~ ll_out,
      .default = aic_out
    )
  ) |>
  transmute(
    claim_id = paste0("a2_", recode(quantity, "N" = "nobs", "Log likelihood" = "loglik",
                                    "AIC" = "aic"), "_", model),
    table_figure = "Appendix Table 2",
    claim = paste0(quantity, ", ", model),
    value_script = value_rewrite,
    value_paper,
    value_rewrite,
    digits = if_else(quantity == "N", 0, 3),
    notes = "Model fit statistic; the deposited script and the rewrite agree exactly"
  )

# Appendix study manifest ----
# Each of the appendix's study descriptions opens with a stated sample size. These are
# the fitted samples of the corresponding models, which is what the appendix reports:
# subjects with a missing or don't-know outcome are dropped, following the original
# authors, as the article says.
fitted_n <- function(tab, key, value) tab$nobs[tab[[key]] == value][1]

manifest_rows <- tribble(
  ~claim_id, ~claim, ~value_paper, ~value_rewrite, ~notes,
  "manifest_welfare_gss84_n", "Welfare, GSS 1984 N", 943, welfare_ns$n[welfare_ns$survey == "GSS84"],
    "Appendix 2.1.1",
  "manifest_welfare_gss14_n", "Welfare, GSS 2014 N", 2457, welfare_ns$n[welfare_ns$survey == "GSS14"],
    "Appendix 2.1.2",
  "manifest_welfare_lucid_n", "Welfare, Lucid N", 1811, welfare_ns$n[welfare_ns$survey == "lucid"],
    "Appendix 2.1.3 states 1,811, which is the Lucid sample size of the Hiscox experiment in section 2.4.2. The welfare data hold 3,504 Lucid rows of which 3,294 have a usable outcome",
  "manifest_welfare_mturk_n", "Welfare, MTurk N", 494, welfare_ns$n[welfare_ns$survey == "mturk"],
    "Appendix 2.1.4",
  "manifest_ad_original_n", "Asian Disease, original N", 307, fitted_n(asian_disease, "survey", "original"),
    "Appendix 2.2.1",
  "manifest_ad_lucid_n", "Asian Disease, Lucid N", 1813, fitted_n(asian_disease, "survey", "lucid"),
    "Appendix 2.2.2",
  "manifest_ks_original_n", "Kam and Simas, original N", 761, fitted_n(kamsimas, "model", "kam_base"),
    "Appendix 2.3.1 states 761 in prose; appendix Table 2 reports 752 for the same models, and 752 is what the data give",
  "manifest_ks_lucid_n", "Kam and Simas, Lucid N", 1629, fitted_n(kamsimas, "model", "lucid_base"),
    "Appendix 2.3.2",
  "manifest_ks_mturk_n", "Kam and Simas, MTurk N", 766, fitted_n(kamsimas, "model", "mturk_base"),
    "Appendix 2.3.3",
  "manifest_hiscox_original_n", "Hiscox, original N", 1578, fitted_n(hiscox, "survey", "hiscox"),
    "Appendix 2.4.1",
  "manifest_hiscox_lucid_n", "Hiscox, Lucid N", 1811, fitted_n(hiscox, "survey", "lucid"),
    "Appendix 2.4.2",
  "manifest_hiscox_gfk_n", "Hiscox, GfK N", 2084, fitted_n(hiscox, "survey", "tess"),
    "Appendix 2.4.3",
  "manifest_hiscox_mturk_n", "Hiscox, MTurk N", 2972, fitted_n(hiscox, "survey", "mturk"),
    "Appendix 2.4.4",
  "manifest_rumors_original_n", "Healthcare rumors, original N", 1593, fitted_n(rumors, "survey", "ssi"),
    "Appendix 2.5.1, which calls the original sample MTurk where the article calls it Survey Sampling International. The data agree with the article",
  "manifest_rumors_lucid_n", "Healthcare rumors, Lucid N", 3503, fitted_n(rumors, "survey", "lucid"),
    "Appendix 2.5.2"
) |>
  mutate(table_figure = "Appendix study manifest", value_script = value_rewrite,
         digits = 0)

# The Hiscox appendix gives a second wave for the GfK and MTurk replications. The deposit
# ships one wave of each, so nothing in the pipeline reaches these two numbers and the
# deposit cannot support the claim either way.
manifest_wave2_rows <- tribble(
  ~claim_id, ~claim, ~value_paper,
  "manifest_hiscox_gfk_wave2_n", "Hiscox, GfK wave 2 N", 1838,
  "manifest_hiscox_mturk_wave2_n", "Hiscox, MTurk wave 2 N", 2307
) |>
  mutate(table_figure = "Appendix study manifest", value_script = NA_real_,
         value_rewrite = NA_real_, digits = 0, defect_locus_fixed = "archive",
         notes = "The deposited Hiscox file carries a single wave per survey, so the second wave is not in the deposit at all")

# Article prose ----
# The article states most of its quantitative content in prose rather than in tables.
# The pipeline values come from text_in_text_claims.csv; the published figures are
# transcribed here, keyed on the same claim labels.
paper_text <- tribble(
  ~claim, ~claim_id, ~value_paper,
  "Lucid sample N", "sample_lucid_n", "3504",
  "Surveys per month, mean", "surveys_per_month_mean", "4.28",
  "Percent taking fewer than one survey per day", "share_under_one_survey_a_day", "98",
  "Surveys per month among those, mean", "surveys_per_month_trimmed", "2.43",
  "Percent taking surveys at home", "share_surveys_at_home", "94",
  "Expected compensation, mean dollars", "compensation_mean", "5.01",
  "Expected compensation, mean dollars, trimmed", "compensation_mean_trimmed", "1.16",
  "Percent female, Lucid", "female_lucid", "52",
  "Percent female, MTurk", "female_mturk", "60",
  "Years of education, Lucid", "education_lucid", "14.2",
  "Years of education, ANES", "education_anes", "13.5",
  "Party ID, Lucid", "party7_lucid", "3.7",
  "Party ID, ANES 2012", "party7_anes2012", "3.7",
  "Party ID, MTurk", "party7_mturk", "3.5",
  "Political interest, Lucid minus MTurk", "interest_lucid_minus_mturk", "1.2",
  "Variables tested", "appendix_opportunities", "21",
  "Lucid closer", "appendix_lucid_closer", "18",
  "MTurk closer", "appendix_mturk_closer", "3",
  "Lucid significantly closer, archive p", "appendix_lucid_closer_significant", "14",
  "MTurk significantly closer, archive p", "appendix_mturk_closer_significant", "1",
  "Demographic variables tested", "demographic_variables_tested", "11",
  "Demographic, Lucid closer", "demographic_lucid_closer", "9",
  "Demographic, significantly closer, archive p", "demographic_significantly_closer", "5",
  "Political, significantly closer, archive p", NA, "3",
  "Traits, significantly closer, archive p", NA, "5",
  "Death panel belief, Lucid control mean", "rumor_lucid_control_mean", "-0.17",
  "Death panel belief, original control mean", "rumor_original_control_mean", "-0.19"
)

# A prose value is written as "52.15 (0.85)", mean then standard error; the article
# quotes the mean alone, so the mean is what is compared.
lead_number <- function(x) as.numeric(str_extract(str_remove_all(x, ","), "^-?[0-9.]+"))

text_rows <- text_claims |>
  left_join(paper_text, by = "claim") |>
  transmute(
    claim_id,
    table_figure = paste0("Text, ", section),
    claim,
    value_script = lead_number(value_pipeline),
    digits = if_else(str_detect(value_paper, "\\."),
                     nchar(str_remove(value_paper, "^.*\\.")), 0),
    value_paper = as.numeric(value_paper),
    value_rewrite = lead_number(value_pipeline),
    notes = if_else(is.na(value_paper),
                    "Computed to support a claim the article states in words rather than in numbers",
                    "")
  )

# The article's count of significant demographic differences is checkable against the
# appendix table alone, without running anything: count the 11 demographic rows of
# paper_appendix_1 that are positive and print a p-value below 0.05. That count is
# computed here from the published values rather than asserted, so the note cannot
# drift from the table it describes.
paper_demographic_vars <- c("female", "education", "age", "income", "race_white",
                            "race_black", "race_hispanic", "region_northeast",
                            "region_midwest", "region_south", "region_west")

paper_demographic_sig <- paper_appendix_1 |>
  filter(variable %in% paper_demographic_vars,
         distance_paper > 0, p_paper < 0.05) |>
  nrow()

text_rows <- text_rows |>
  mutate(notes = if_else(
    claim == "Demographic, significantly closer, archive p",
    as.character(str_glue(
      "The article's prose says five. Its own appendix Table 1 prints ",
      "{paper_demographic_sig} demographic rows that are both positive and below 0.05, ",
      "which is what the pipeline reproduces, so the disagreement is between the ",
      "article's text and the article's table")),
    notes
  ))

# Claims the article states in words ----
# A sentence about shape, sign or count has no number to compare, so it carries a truth
# value instead: holds is 1 where the estimates support the sentence and 0 where they
# contradict it, and match stays NA because there is nothing to match. The verdicts are
# read out of maintained/output/text_descriptive_claims.csv rather than computed here,
# for the same reason every other value in this file is read rather than typed.
descriptive <- out("text_descriptive_claims.csv")

descriptive_locus <- tribble(
  ~claim_id, ~defect_locus_fixed, ~note,
  "mturk_overrepresents_southerners", "paper_internal",
    "The MTurk southern share sits below the ANES 2012 benchmark on the article's own Figure 1, so southerners are under-represented rather than over-represented",
  "lucid_closer_registration_and_turnout", "unresolved",
    "The article's own appendix Table 1 puts MTurk closer on turnout, and the article says so itself two paragraphs later. The two deposited files disagree: the standardized file the distance tests read puts the ANES 2012 turnout benchmark at 0.702 and the political table's weighted mean puts it at 0.756, and Lucid is closer under the second. Choosing between them is an analytical decision the rewrite does not make",
  "traits_all_five_significantly_closer", "paper_internal",
    "Under the two-tailed test the appendix says it used, four of the five traits are significantly closer and extraversion is not. All five clear 0.05 under the expression the published p-value column actually carries",
  "appendix_two_tailed_method", "archive",
    "The deposited 12_DistanceTests.R computes pnorm(2 * (1 - |z|)), which is not a p-value for any hypothesis, where the appendix text says two-tailed under a normal approximation",
  "policy_lucid_more_conservative", "unresolved",
    "The sentence names neither the items nor the direction, and the two tax items have no unambiguous conservative side, so the claim is not judgeable as written",
  "one_substantively_different_result", "unresolved",
    "The sentence does not say what makes a result substantively different. Two experiments carry at least one Lucid estimate that differs from the original in sign or significance"
)

descriptive_rows <- descriptive |>
  left_join(published_claims, by = "claim_id") |>
  left_join(descriptive_locus, by = "claim_id") |>
  transmute(
    claim_id,
    table_figure = paste0("Text, ", location),
    claim = evidence,
    value_script = value,
    value_paper = as.numeric(value_paper),
    value_rewrite = value,
    digits = 0,
    holds = as.numeric(holds),
    defect_locus_fixed,
    notes = coalesce(note, "Computed from the estimates the pipeline produces; the article states the claim in words")
  )

# Quantities the article states in passing that the pipeline can nonetheless reach ----
# A design parameter is read back rather than asserted wherever something in output/ can
# answer it: a confidence level is implied by the half widths of the intervals, and the
# number of levels of a factor by the indicators its regression carries.
recoverable <- tribble(
  ~claim_id, ~table_figure, ~claim, ~value_rewrite, ~digits, ~notes,
  "intro_five_experiments", "Text, Fit for purpose", "Experiments replicated",
    n_distinct(out("figure_2_standardized_experiments.csv")$facet), 0,
    "Counted from the facets of Figure 2",
  "figure_1_standardization", "Figure 1", "ANES 2012 standardized to mean zero",
    max(abs(out("figure_1_standardized_demos.csv")$mean[
      out("figure_1_standardized_demos.csv")$survey == "anes2012"])), 3,
    "The article says Figure 1 standardizes by the ANES 2012 mean and standard deviation, which puts every ANES 2012 point at zero",
  "hc2_ci_level", "Text, Experiments", "Confidence level",
    100 * (2 * pnorm(mean(with(asian_disease, (conf.high - estimate) / std.error))) - 1), 0,
    "Implied by the half widths of the Asian Disease intervals in standard errors, under a normal approximation",
  "hiscox_expert_levels", "Text, Experiment 4", "Levels of the expert factor",
    1 + sum(str_detect(unique(hiscox$term), "expert$")), 0,
    "The omitted level plus the indicators the regression carries",
  "hiscox_valence_levels", "Text, Experiment 4", "Levels of the valence factor",
    1 + sum(str_detect(unique(hiscox$term), "valence")), 0,
    "The omitted control plus the indicators the regression carries",
  "welfare_gss_year", "Text, Treatment effect heterogeneity", "GSS baseline year",
    max(if_else(as.numeric(str_remove(str_subset(welfare_ns$survey, "^GSS"), "^GSS")) < 50,
                2000 + as.numeric(str_remove(str_subset(welfare_ns$survey, "^GSS"), "^GSS")),
                1900 + as.numeric(str_remove(str_subset(welfare_ns$survey, "^GSS"), "^GSS")))),
    0,
    "The heterogeneity section names the 2016 GSS. The deposited welfare data hold the 1984 and 2014 surveys and no other, and the article's own Experiment 1 section names 2014 as the baseline. The deposited heterogeneity file labels the comparison sample Original with no year, so which of the two it is cannot be settled from the deposit"
) |>
  left_join(select(published_claims, claim_id, value_paper), by = "claim_id") |>
  mutate(value_paper = as.numeric(value_paper), value_script = value_rewrite)

recoverable$defect_locus_fixed <- if_else(recoverable$claim_id == "welfare_gss_year",
                                          "unresolved", NA_character_)

# The standardization claim prints no number in the article, so it has no value to match
# against and is verified by its own arithmetic instead: every ANES 2012 point sits at
# zero exactly when the ANES 2012 is the standardizing sample.
recoverable$holds <- if_else(recoverable$claim_id == "figure_1_standardization",
                             as.numeric(recoverable$value_rewrite < 1e-9), NA_real_)

# Figures ----
# None of the five figures prints a number, so none has a published value to compare
# against. Each script now writes the values it plots, so the estimates are diffable
# even though the published figures are not.
figure_rows <- imap_dfr(figure_files, function(f, label) {
  d <- out(f)
  tibble(
    table_figure = label,
    claim = "All plotted estimates and confidence bounds",
    value_script = NA_real_,
    value_paper = NA_real_,
    value_rewrite = NA_real_,
    digits = NA_real_,
    notes = str_glue("The published figure prints no numbers. Its {nrow(d)} plotted estimates are drawn from a data file the deposit ships pre-computed and are written to maintained/output/{f}")
  )
})

table_1_row <- tibble(
  table_figure = "Table 1",
  claim = "Theoretical applicability of five experimental studies",
  value_script = NA_real_,
  value_paper = NA_real_,
  value_rewrite = NA_real_,
  digits = NA_real_,
  notes = "The article's only table is a prose summary of the scope conditions of the five experiments and contains no numeric content"
)

# Assemble ----
gt <- bind_rows(
  a1_distance, a1_se, a1_p, a1_p_twotail,
  a2_coef, a2_se, a2_fit,
  manifest_rows |> select(claim_id, table_figure, claim, value_script, value_paper,
                          value_rewrite, digits, notes),
  manifest_wave2_rows,
  text_rows,
  descriptive_rows,
  recoverable,
  figure_rows,
  table_1_row
)

# Agreement at the precision the paper prints ----
# The tolerance has to come from how the article prints a number, not from the number
# itself: a published 0.100 and a published 0.1 are different claims, and reading the
# precision back off the numeric value cannot tell them apart, since it sees 0.1 either
# way. Every block above therefore carries the digit count the published table uses.
agrees <- function(value, target, digits) {
  case_when(
    is.na(value) | is.na(target) | is.na(digits) ~ NA_real_,
    abs(value - target) <= 0.5 * 10^(-digits) ~ 1,
    .default = 0
  )
}

gt <- gt |>
  mutate(
    paper_id = "coppock_mcclellan_2019",
    match = agrees(value_script, value_paper, digits),
    match_rewrite = agrees(value_rewrite, value_paper, digits)
  )

# The bootstrap quantities are Monte Carlo draws, not fixed numbers, so agreement to
# printed precision is the wrong test for them and the interval test replaces it.
stochastic <- !is.na(gt$in_interval)
gt$match[stochastic] <- gt$in_interval[stochastic]
gt$match_rewrite[stochastic] <- gt$in_interval[stochastic]

# Where the rewrite does not match, say where the disagreement lives ----
# A zero here almost never means the rewrite is wrong, so every one of them says where the
# fault sits. The rows whose locus is fixed by hand carry it in defect_locus_fixed, set
# beside the claim it belongs to rather than in a list of claim labels far from them.
gt <- gt |>
  mutate(
    # A row is adverse when ANY verdict is 0. Keying the locus on match_rewrite alone
    # exempts the archive-fails-while-the-rewrite-matches shape, which is 25 of the
    # rows below and the commonest adverse shape in this paper.
    adverse = (!is.na(match) & match == 0) |
      (!is.na(match_rewrite) & match_rewrite == 0) |
      (!is.na(holds) & holds == 0),
    defect_locus = case_when(
      !is.na(defect_locus_fixed) ~ defect_locus_fixed,
      !adverse ~ NA_character_,
      # Appendix Table 2's standard errors. The table's own note says HC2, the deposited
      # script passes no se = argument and so prints the model-based SE, and the rewrite
      # reproduces the published value. The deposit is the side that fails.
      match == 0 & match_rewrite == 1 & str_starts(claim, "SE, ") ~ "archive",
      claim %in% c("Welfare, Lucid N", "Kam and Simas, original N",
                   "Demographic, significantly closer, archive p") ~ "paper_internal",
      .default = "unresolved"
    ),
    notes = if_else(
      match_rewrite == 0 & str_starts(claim, "Bootstrap SE, "),
      paste0(as.character(notes),
             ". The published value sits outside that range. The sampler change of R 3.6 ",
             "does not account for it: the range is no wider under RNGkind(sample.kind = ",
             "\"Rounding\"). One exceedance in 21 variables is what a 95 per cent interval ",
             "produces by chance, so the cause is not established"),
      as.character(notes)
    )
  )

stopifnot(!anyDuplicated(na.omit(gt$claim_id)))

# Gate: the transcription agrees with itself ----
# The published values above and those in published_claims.csv are two readings of the
# same pages, so a disagreement between them means one of the two has drifted.
transcription_gaps <- gt |>
  drop_na(claim_id, value_paper) |>
  inner_join(select(published_claims, claim_id, extraction = value_paper),
             by = "claim_id") |>
  filter(!is.na(extraction),
         abs(value_paper - as.numeric(extraction)) > 1e-9)

if (nrow(transcription_gaps) > 0) {
  print(select(transcription_gaps, claim_id, value_paper, extraction), n = 40)
  stop(str_glue("The ground truth and ground_truth/published_claims.csv disagree about ",
                "{nrow(transcription_gaps)} published values."))
}

# Gate: the second instrument ran, printed, and agrees ----
# maintained/in_text_claims.R reaches the same claimed numbers out of the same outputs by
# its own path, doing its own selection, unit conversion and rounding. It is run here
# rather than read, and what it printed is counted: a block that errors at its first line,
# or that ends in a bare expression and so prints nothing under source(), passes a scan for
# markers while checking nothing at all.
#
# It is sourced into an environment of its own. Both files read the same pipeline outputs
# and name their objects for what they hold, so sourcing into the global environment would
# quietly replace this file's published_claims, distances and probit with the other file's,
# and every gate below would then be checking the wrong objects.
claims_output <- capture.output(
  source(here::here("maintained", "in_text_claims.R"), local = new.env())
)

printed_claims <- tibble(line = claims_output) |>
  filter(str_starts(line, "CLAIM ")) |>
  transmute(
    claim_id = str_match(line, "^CLAIM ([^ ]+) = ")[, 2],
    value_in_text = str_match(line, "^CLAIM [^ ]+ = (.*?) \\|\\| ")[, 2]
  )

stopifnot(!anyDuplicated(printed_claims$claim_id), !any(is.na(printed_claims$claim_id)),
          !any(is.na(printed_claims$value_in_text)))

must_check <- filter(published_claims, needs_block)

blockless <- setdiff(must_check$claim_id, printed_claims$claim_id)
invented <- setdiff(printed_claims$claim_id, must_check$claim_id)
rowless <- published_claims |>
  filter(claim_type %in% c("pipeline", "descriptive")) |>
  pull(claim_id) |>
  setdiff(na.omit(gt$claim_id))

if (length(blockless) > 0 || length(rowless) > 0 || length(invented) > 0) {
  stop(str_glue(
    "Coverage gate failed. ",
    "Claims with no block in maintained/in_text_claims.R ({length(blockless)}): ",
    "{str_c(head(blockless, 40), collapse = ', ')}. ",
    "Claims with no ground truth row ({length(rowless)}): ",
    "{str_c(head(rowless, 40), collapse = ', ')}. ",
    "Blocks naming a claim the extraction does not require ({length(invented)}): ",
    "{str_c(head(invented, 40), collapse = ', ')}."
  ))
}

stopifnot(nrow(printed_claims) == nrow(must_check))

# The two instruments must land on the same number. in_text_claims.R prints at the
# article's own precision and never sees this file, so a disagreement is one of the two
# being wrong and it stops the build.
format_to_page <- function(value, digits) {
  text <- sprintf(paste0("%.", digits, "f"), value)
  if_else(str_detect(text, "^-0[.]?0*$"), str_remove(text, "^-"), text)
}

instrument_disagreements <- gt |>
  drop_na(claim_id, value_rewrite, digits) |>
  inner_join(printed_claims, by = "claim_id") |>
  filter(format_to_page(value_rewrite, digits) != value_in_text)

if (nrow(instrument_disagreements) > 0) {
  print(select(instrument_disagreements, claim_id, value_paper, value_rewrite,
               value_in_text), n = 40)
  stop(str_glue("The ground truth and maintained/in_text_claims.R disagree on ",
                "{nrow(instrument_disagreements)} claims."))
}

# Gate: a verdict and a locus go together ----
# A failure with no locus reads as a fault in the rewrite, which it almost never is; a
# locus with no failure is a verdict nothing supports. A claim the article makes that
# neither instrument can compare either way needs a locus too, since that is exactly the
# shape that otherwise disappears into the unverifiable bucket. A row is failing when
# ANY of the three verdicts is 0, so a row the archive misses and the rewrite matches
# is a failure here, not a pass.
failing <- (!is.na(gt$match) & gt$match == 0) |
  (!is.na(gt$match_rewrite) & gt$match_rewrite == 0) |
  (!is.na(gt$holds) & gt$holds == 0)
passing <- !failing &
  ((!is.na(gt$match_rewrite) & gt$match_rewrite == 1) |
     (!is.na(gt$holds) & gt$holds == 1))
uncompared <- !is.na(gt$claim_id) & is.na(gt$match_rewrite) & is.na(gt$holds)

locus_gate <- gt[(failing & is.na(gt$defect_locus)) |
                   (passing & !is.na(gt$defect_locus)) |
                   (uncompared & is.na(gt$defect_locus)), ]

if (nrow(locus_gate) > 0) {
  print(select(locus_gate, claim_id, table_figure, claim, match_rewrite, holds,
               defect_locus), n = 40)
  stop("Rows carrying a failure with no locus, a locus with no failure, or a claim compared by nothing.")
}

# value_paper is committed as the string the article prints ----
# The comparisons above need it as a number, and the committed file needs it as a string:
# 0.100 and 0.1 are the same double and different claims, and a reader of the CSV can only
# see which one the page carries if the digits survive. The digit count each block already
# recorded is what renders it, and where the extraction carries the same claim the two
# strings must agree, which is a stricter test than the numeric one above and catches a
# block whose digits are right about the value and wrong about the precision.
stopifnot(!any(!is.na(gt$value_paper) & is.na(gt$digits)))

gt <- gt |>
  mutate(value_paper_printed = if_else(
    is.na(value_paper), NA_character_,
    format_to_page(value_paper, replace_na(digits, 0))))

printed_gaps <- gt |>
  drop_na(claim_id, value_paper_printed) |>
  inner_join(select(published_claims, claim_id, extraction = value_paper),
             by = "claim_id") |>
  filter(!is.na(extraction), value_paper_printed != extraction)

if (nrow(printed_gaps) > 0) {
  print(select(printed_gaps, claim_id, value_paper_printed, extraction), n = 40)
  stop(str_glue("The ground truth prints {nrow(printed_gaps)} published values at a ",
                "different precision from ground_truth/published_claims.csv."))
}

gt <- gt |>
  mutate(value_paper = value_paper_printed) |>
  select(paper_id, claim_id, table_figure, claim, value_script, value_paper, match,
         value_rewrite, match_rewrite, holds, defect_locus, notes)

write_csv(gt, here::here("ground_truth", "coppock_mcclellan_2019_ground_truth.csv"))

print(gt |> select(table_figure, claim, value_script, value_paper, match, value_rewrite,
                   match_rewrite, holds, defect_locus),
      n = nrow(gt))

print(tibble(
  rows = nrow(gt),
  comparable = sum(!is.na(gt$match_rewrite)),
  script_match = sum(gt$match == 1, na.rm = TRUE),
  script_fail = sum(gt$match == 0, na.rm = TRUE),
  rewrite_match = sum(gt$match_rewrite == 1, na.rm = TRUE),
  rewrite_fail = sum(gt$match_rewrite == 0, na.rm = TRUE)
))
