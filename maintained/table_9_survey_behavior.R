# coppock_mcclellan_2019/maintained/table_9_survey_behavior.R
# Output: output/table_9_survey_behavior.csv
# Depends on: helpers.R, original/ReplicationArchive/SurveyBehavior.RData
# Description: Self-reported survey-taking behavior among the Lucid respondents, the
#   archive's script 09. The archive README calls this Table 9; the published article
#   prints no such table, but its "Subject recruitment" paragraph states several of
#   these numbers in prose, and text_in_text_claims.R checks them against this file.
#   The _trim columns drop respondents reporting more than one survey a day, and
#   expected compensation above twenty dollars.

source(here::here("maintained", "helpers.R"))

load(file.path(data_dir, "SurveyBehavior.RData"))

entries <- lucid_survey |>
  weighted_mean_se_entries(
    dont_multiply = c("numsurvey", "numsurvey_trim",
                      "surveycompamount", "surveycompamount_trim")
  )

ns <- lucid_survey |>
  group_by(survey) |>
  summarize(entry = comma(n()), .groups = "drop") |>
  mutate(variable = "n")

row_order <- c(
  "numsurvey", "numsurvey_trim",
  "surveylocation_home", "surveylocation_work", "surveylocation_public",
  "surveylocation_other",
  "surveycomptype_dollars", "surveycomptype_points", "surveycomptype_bitcoin",
  "surveycomptype_currency", "surveycomptype_nocomp",
  "surveycompamount", "surveycompamount_trim",
  "n"
)

survey_table <- bind_rows(
  entries |> select(survey, variable, entry),
  ns
) |>
  pivot_wider(names_from = survey, values_from = entry) |>
  filter(variable %in% row_order) |>
  mutate(variable = factor(variable, levels = row_order)) |>
  arrange(variable) |>
  select(variable, lucid)

write_csv(survey_table, file.path(out_dir, "table_9_survey_behavior.csv"))
