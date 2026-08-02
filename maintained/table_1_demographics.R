# coppock_mcclellan_2019/maintained/table_1_demographics.R
# Output: output/table_1_demographics.csv
# Depends on: helpers.R, original/ReplicationArchive/DemosTableStacked.rdata
# Description: Demographic means and standard errors by sample, the archive's script 01.
#   The archive README calls this Table 1. The published article prints no such table:
#   its Table 1 is a prose summary of the five experiments, and these quantities reach
#   print only in standardized form, as Figure 1.

source(here::here("maintained", "helpers.R"))

load(file.path(data_dir, "DemosTableStacked.rdata"))

# Non-income variables ----
# The archive drops the income columns here and handles them separately below,
# because income is reported in dollars rather than as a percentage or a level.
entries <- demos_stacked |>
  filter(survey != "cps_income") |>
  select(-contains("income")) |>
  weighted_mean_se_entries(dont_multiply = c("age", "education"))

# Income ----
# CPS income comes from a different CPS extract, stacked under survey == "cps_income";
# it is renamed to "cps" once the rows from the main CPS extract are dropped.
income_entries <- demos_stacked |>
  group_by(survey) |>
  summarize(
    income_mean = dollar(weighted.mean(income, w = weights, na.rm = TRUE)),
    income_median = dollar(weightedMedian(income, w = weights, na.rm = TRUE)),
    .groups = "drop"
  ) |>
  filter(survey != "cps") |>
  mutate(survey = if_else(survey == "cps_income", "cps", survey)) |>
  pivot_longer(-survey, names_to = "variable", values_to = "entry")

# Sample sizes ----
ns <- demos_stacked |>
  filter(survey != "cps_income") |>
  group_by(survey) |>
  summarize(entry = comma(n()), .groups = "drop") |>
  mutate(variable = "n")

row_order <- c(
  "female", "age", "education", "income_mean", "income_median",
  "race_white", "race_black", "race_hispanic", "race_asian", "race_native",
  "region_northeast", "region_midwest", "region_south", "region_west", "n"
)

demo_table <- bind_rows(
  entries |> select(survey, variable, entry),
  income_entries,
  ns
) |>
  pivot_wider(names_from = survey, values_from = entry) |>
  filter(variable %in% row_order) |>
  mutate(variable = factor(variable, levels = row_order)) |>
  arrange(variable) |>
  select(variable, lucid, mturk, anes_panel, cps, anes, anes2012)

write_csv(demo_table, file.path(out_dir, "table_1_demographics.csv"))
