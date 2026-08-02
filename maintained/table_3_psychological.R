# coppock_mcclellan_2019/maintained/table_3_psychological.R
# Output: output/table_3_psychological.csv
# Depends on: helpers.R, original/ReplicationArchive/PsychTableStacked.RData
# Description: Big Five traits, need for cognition, need to evaluate, and risk acceptance
#   by sample, the archive's script 03. The archive README calls this Table 3; the
#   published article prints no such table.
#   Every entry stays on its original scale, so nothing is rescaled to a percentage.

source(here::here("maintained", "helpers.R"))

load(file.path(data_dir, "PsychTableStacked.RData"))

psych_vars <- c(
  "agreeableness", "conscientiousness", "emotionalstability", "extraversion",
  "opennesstoexperiences", "ramean", "NFC", "NTE"
)

entries <- psych_stacked |>
  weighted_mean_se_entries(dont_multiply = psych_vars)

# MTurk measured need for cognition, need to evaluate, and risk acceptance only in
# the separate risk-battery study, stacked under survey == "mturk_risk". The archive
# moves those three cells into the MTurk column and then drops the mturk_risk row.
mturk_risk_entries <- entries |>
  filter(survey == "mturk_risk", variable %in% c("NFC", "NTE", "ramean")) |>
  mutate(survey = "mturk")

entries <- entries |>
  filter(!(survey == "mturk" & variable %in% c("NFC", "NTE", "ramean"))) |>
  filter(survey != "mturk_risk") |>
  bind_rows(mturk_risk_entries)

ns <- psych_stacked |>
  filter(survey != "mturk_risk") |>
  group_by(survey) |>
  summarize(entry = comma(n()), .groups = "drop") |>
  mutate(variable = "n")

row_order <- c(psych_vars[1:5], "ramean", "NFC", "NTE", "n")

psych_table <- bind_rows(
  entries |> select(survey, variable, entry),
  ns
) |>
  pivot_wider(names_from = survey, values_from = entry) |>
  filter(variable %in% row_order) |>
  mutate(variable = factor(variable, levels = row_order)) |>
  arrange(variable) |>
  select(variable, lucid, mturk, cces, ccap, anes_panel, anes, anes2012, kam)

write_csv(psych_table, file.path(out_dir, "table_3_psychological.csv"))
