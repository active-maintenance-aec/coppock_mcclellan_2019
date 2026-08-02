# coppock_mcclellan_2019/maintained/text_in_text_claims.R
# Output: output/text_in_text_claims.csv
# Depends on: helpers.R and every table script's output; the archive's SurveyBehavior.RData
# Description: Every number stated in the body of the article, paired with the pipeline
#   output that produces it. The article prints almost no tables, so most of its
#   quantitative content lives in prose, and this file is where it gets checked.
#   No published number appears here in any form. Each value is read from output/ or
#   recomputed from the deposited data; the sentence it answers is quoted above it as a
#   comment, and the figure the article prints is joined on in the ground truth, which
#   is the one place published values are written down.

source(here::here("maintained", "helpers.R"))

options(width = 200)

demos <- read_csv(file.path(out_dir, "table_1_demographics.csv"), show_col_types = FALSE)
politics <- read_csv(file.path(out_dir, "table_2_political.csv"), show_col_types = FALSE)
behavior <- read_csv(file.path(out_dir, "table_9_survey_behavior.csv"), show_col_types = FALSE)
rumors <- read_csv(file.path(out_dir, "table_8_health_rumors.csv"), show_col_types = FALSE)
distances <- read_csv(file.path(out_dir, "appendix_table_1_distance_tests.csv"),
                      show_col_types = FALSE)
counts <- read_csv(file.path(out_dir, "appendix_table_1_distance_counts.csv"),
                   show_col_types = FALSE)

load(file.path(data_dir, "SurveyBehavior.RData"))

cell <- function(tab, var, col) tab[[col]][tab$variable == var]

# Our sample ----
# "As we only have a single sample of 3504 subjects obtained in March of 2016"
# "Respondents report taking an average of 4.28 surveys per month."
# "However, 98% of respondents report taking fewer than one survey per day; the average
#  number of surveys per month among these respondents is 2.43."
# "The vast majority of subjects (94%) take surveys at home"
# "Unconditionally, the average compensation amount that subjects reported expecting was
#  US$5.01, but if we trim off responses that are implausible (greater than US$20.00),
#  we obtain the more reasonable figure of US$1.16."
share_under_one_a_day <- mean(!is.na(lucid_survey$numsurvey_trim)) * 100

sample_claims <- tribble(
  ~claim, ~value_pipeline,
  "Lucid sample N", cell(demos, "n", "lucid"),
  "Surveys per month, mean", cell(behavior, "numsurvey", "lucid"),
  "Percent taking fewer than one survey per day", sprintf("%.2f", share_under_one_a_day),
  "Surveys per month among those, mean", cell(behavior, "numsurvey_trim", "lucid"),
  "Percent taking surveys at home", cell(behavior, "surveylocation_home", "lucid"),
  "Expected compensation, mean dollars", cell(behavior, "surveycompamount", "lucid"),
  "Expected compensation, mean dollars, trimmed", cell(behavior, "surveycompamount_trim", "lucid")
)

# Baseline characteristics ----
# "The Lucid sample was 52% female - much closer to the Census value of 50.8% than the
#  60% female sample collect on MTurk."  The 50.8% Census benchmark is cited from
#  outside the deposit and is not computable here.
# "The mean number of years of education on Lucid (14.2) is higher than the approximately
#  13.5 years recorded by the ANES survey, but is closer than MTurk sample estimates."
# "the Lucid mean of 3.7 is identical to that collected in the 2012 ANES, while the MTurk
#  average is slightly lower at 3.5"
# "The difference between Lucid and MTurk is large, about 1.2 points on the five-point
#  political interest scale."
# "MTurk respondents scored higher on political knowledge then did respondents on the
#  ANES panel, while Lucid respondents scored nearly identically."
interest_gap <- as.numeric(str_extract(cell(politics, "interest", "lucid"), "^[0-9.]+")) -
  as.numeric(str_extract(cell(politics, "interest", "mturk"), "^[0-9.]+"))

baseline_claims <- tribble(
  ~claim, ~value_pipeline,
  "Percent female, Lucid", cell(demos, "female", "lucid"),
  "Percent female, MTurk", cell(demos, "female", "mturk"),
  "Years of education, Lucid", cell(demos, "education", "lucid"),
  "Years of education, ANES", cell(demos, "education", "anes"),
  "Years of education, MTurk", cell(demos, "education", "mturk"),
  "Party ID, Lucid", cell(politics, "party7", "lucid"),
  "Party ID, ANES 2012", cell(politics, "party7", "anes2012"),
  "Party ID, MTurk", cell(politics, "party7", "mturk"),
  "Political interest, Lucid minus MTurk", sprintf("%.2f", interest_gap),
  "Political knowledge, Lucid", cell(politics, "knowl_score", "lucid"),
  "Political knowledge, MTurk", cell(politics, "knowl_score", "mturk"),
  "Political knowledge, ANES panel", cell(politics, "knowl_score", "anes_panel")
)

# Distance tests ----
# "Out of the 11 demographic variables that are measured for both Lucid and MTurk, the
#  Lucid mean is closer to the ANES mean in nine instances, five of which are
#  statistically significant."  (Article, p.6.)
# "Out of 21 opportunities, Lucid is closer to the ANES 18 times, 14 of which are
#  significant. By contrast, MTurk is closer in only 3 instances, and significant in only
#  one (voter turnout)."  (Online appendix, section 1.)
# "Lucid is significantly closer to the ANES 2012 on party identification, ideology, and
#  political interest, while MTurk is significantly closer for voter turnout."
# "Formal hypothesis tests demonstrate that Lucid is significantly closer to the ANES 2012
#  than MTurk on all five traits."
demographic_vars <- c("female", "education", "age", "income", "race_white", "race_black",
                      "race_hispanic", "region_northeast", "region_midwest",
                      "region_south", "region_west")
political_vars <- c("register", "vote", "party7", "ideology", "interest")
trait_vars <- c("extraversion", "agreeableness", "conscientiousness",
                "emotionalstability", "opennesstoexperiences")

count_block <- function(vars, p_col) {
  d <- filter(distances, variable %in% vars)
  c(closer = sum(d$lucid_is_closer > 0),
    sig_closer = sum(d$lucid_is_closer > 0 & d[[p_col]] < 0.05))
}

distance_claims <- tribble(
  ~claim, ~value_pipeline,
  "Variables tested", as.character(counts$n_variables),
  "Lucid closer", as.character(counts$n_lucid_closer),
  "MTurk closer", as.character(counts$n_mturk_closer),
  "Lucid significantly closer, archive p", as.character(counts$n_sig_closer_archive),
  "MTurk significantly closer, archive p", as.character(counts$n_sig_farther_archive),
  "Lucid significantly closer, two-tailed p", as.character(counts$n_sig_closer_twotail),
  "MTurk significantly closer, two-tailed p", as.character(counts$n_sig_farther_twotail),
  "Demographic variables tested", as.character(sum(distances$variable %in% demographic_vars)),
  "Demographic, Lucid closer", as.character(count_block(demographic_vars, "p_archive")[["closer"]]),
  "Demographic, significantly closer, archive p", as.character(count_block(demographic_vars, "p_archive")[["sig_closer"]]),
  "Political, significantly closer, archive p", as.character(count_block(political_vars, "p_archive")[["sig_closer"]]),
  "Traits, significantly closer, archive p", as.character(count_block(trait_vars, "p_archive")[["sig_closer"]]),
  "Traits, significantly closer, two-tailed p", as.character(count_block(trait_vars, "p_twotail")[["sig_closer"]])
)

# Healthcare rumors ----
# "On a -1 to 1 scale (with 0 indicating the respondent was "not sure"), average levels of
#  belief were -0.17 on Lucid, compared with -0.19 in the original."
control_mean <- function(s) {
  rumors |>
    filter(survey == s, term == "(Intercept)") |>
    pull(estimate) |>
    sprintf(fmt = "%.3f")
}

rumor_claims <- tribble(
  ~claim, ~value_pipeline,
  "Death panel belief, Lucid control mean", control_mean("lucid"),
  "Death panel belief, original control mean", control_mean("ssi")
)

all_claims <- bind_rows(
  sample_claims |> mutate(section = "Our sample"),
  baseline_claims |> mutate(section = "Baseline characteristics"),
  distance_claims |> mutate(section = "Distance tests"),
  rumor_claims |> mutate(section = "Healthcare rumors")
) |>
  select(section, claim, value_pipeline)

print(all_claims, n = nrow(all_claims))

write_csv(all_claims, file.path(out_dir, "text_in_text_claims.csv"))
