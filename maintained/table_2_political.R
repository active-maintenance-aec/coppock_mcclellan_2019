# coppock_mcclellan_2019/maintained/table_2_political.R
# Output: output/table_2_political.csv
# Depends on: helpers.R, original/ReplicationArchive/PoliticsTableStacked.RData
# Description: Political behavior, traits, and policy opinions by sample, the archive's
#   script 02. The archive README calls this Table 2, and the article twice refers the
#   reader to "the online appendix, Table 2" for political knowledge and policy
#   preferences. The published online appendix has no such table: its Table 2 is the
#   Kam and Simas probit specification. The quantities in this file therefore reach
#   print only through Figure 1 and through the prose claims that text_in_text_claims.R
#   checks.

source(here::here("maintained", "helpers.R"))

load(file.path(data_dir, "PoliticsTableStacked.RData"))

entries <- politics_stacked |>
  weighted_mean_se_entries(dont_multiply = c("party7", "ideology", "interest"))

ns <- politics_stacked |>
  group_by(survey) |>
  summarize(entry = comma(n()), .groups = "drop") |>
  mutate(variable = "n")

row_order <- c(
  "register", "vote",
  "party7", "ideology", "interest", "knowl_score",
  "seniors", "healthcare", "immigration", "gaymarriage", "taxrich", "taxpoor",
  "n"
)

politics_table <- bind_rows(
  entries |> select(survey, variable, entry),
  ns
) |>
  pivot_wider(names_from = survey, values_from = entry) |>
  filter(variable %in% row_order) |>
  mutate(variable = factor(variable, levels = row_order)) |>
  arrange(variable) |>
  select(variable, lucid, mturk, anes_panel, cps, anes, anes2012)

write_csv(politics_table, file.path(out_dir, "table_2_political.csv"))
