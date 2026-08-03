# coppock_mcclellan_2019/maintained/text_descriptive_claims.R
# Output: output/text_descriptive_claims.csv
# Depends on: helpers.R and the table and figure scripts' output
# Description: The article states most of its comparisons in words rather than in numbers:
#   which sample sits closer to a benchmark, whether a set of conditional effects can be
#   told apart, in how many cases a replication matched. Each such sentence gets a truth
#   value here, computed from the estimates the pipeline already produced.
#
#   These verdicts belong in output/ rather than in a claims file. A number computed only
#   in the claims file escapes both the run-twice determinism diff and the
#   `git status --porcelain maintained/output/` acceptance test, which is exactly the
#   check a qualitative claim most needs, since nothing else in the pipeline pins it down.
#   No published number is used as an input to any comparison below.

source(here::here("maintained", "helpers.R"))

out <- function(f) read_csv(file.path(out_dir, f), show_col_types = FALSE)

demos <- out("table_1_demographics.csv")
politics <- out("table_2_political.csv")
psych <- out("table_3_psychological.csv")
behavior <- out("table_9_survey_behavior.csv")
distances <- out("appendix_table_1_distance_tests.csv")
fig1 <- out("figure_1_standardized_demos.csv")
fig2 <- out("figure_2_standardized_experiments.csv")
fig3 <- out("figure_3_cate_welfare_ad_ks.csv")
fig4 <- out("figure_4_cate_hiscox.csv")
fig5 <- out("figure_5_cate_berinsky.csv")

# The descriptive tables print "52.15 (0.85)", the mean then its standard error.
entry <- function(tab, var, col) {
  value <- tab[[col]][tab$variable == var]
  stopifnot(length(value) == 1)
  as.numeric(str_remove_all(str_extract(value, "^[$]?-?[0-9,.]+"), "[$,]"))
}

# The standardized figure carries each sample's distance from the ANES 2012 benchmark in
# standard deviations, with the benchmark itself at zero, so a sign read off it is a
# statement about over- or under-representation without any subtraction.
standardized <- function(var, survey_id) {
  value <- fig1$mean[fig1$variable == var & fig1$survey == survey_id]
  stopifnot(length(value) == 1)
  value
}

closer <- function(var) {
  value <- distances$lucid_is_closer[distances$variable == var]
  stopifnot(length(value) == 1)
  value
}

p_archive <- function(var) {
  value <- distances$p_archive[distances$variable == var]
  stopifnot(length(value) == 1)
  value
}

overlap <- function(d) max(d$li) <= min(d$ui)

z_between <- function(d) {
  wide <- d |>
    select(facet, condition, Survey, coef, se) |>
    pivot_wider(names_from = Survey, values_from = c(coef, se))
  mutate(wide, z = (coef_Lucid - coef_Original) / sqrt(se_Lucid^2 + se_Original^2))
}

# Replication pairs ----
pairs <- fig2 |>
  filter(Survey %in% c("Lucid", "Original")) |>
  select(facet, variable, Survey, coef, li, ui) |>
  pivot_wider(names_from = Survey, values_from = c(coef, li, ui)) |>
  mutate(
    same_sign = sign(coef_Lucid) == sign(coef_Original),
    sig_lucid = li_Lucid > 0 | ui_Lucid < 0,
    sig_original = li_Original > 0 | ui_Original < 0
  )

# Blocks of variables the article groups in a sentence ----
four_demographics <- c("female", "education", "age", "income")
trait_vars <- c("extraversion", "agreeableness", "conscientiousness",
                "emotionalstability", "opennesstoexperiences")
interest_samples <- c("lucid", "mturk", "anes_panel", "anes", "anes2012")
seniors_samples <- c("lucid", "mturk", "anes_panel", "anes")

interest_means <- map_dbl(interest_samples, ~ entry(politics, "interest", .x))
seniors_means <- map_dbl(seniors_samples, ~ entry(politics, "seniors", .x))
age_means <- map_dbl(seniors_samples, ~ entry(demos, "age", .x))

# Conservative direction of the four policy items that have one. The two tax items are
# left out: support for a higher rate above 200,000 dollars and support for a higher rate
# below it do not point the same way, and the sentence does not say which items it means.
conservative_direction <- c(seniors = -1, healthcare = -1, immigration = -1, gaymarriage = 1)

lucid_more_conservative <- imap_lgl(
  conservative_direction,
  ~ .x * (entry(politics, .y, "lucid") - entry(politics, .y, "mturk")) > 0
)

# The heterogeneity figures cover one experiment each except Figure 3, whose facets are
# three experiments; the Asian Disease facet carries average effects only.
cate_experiments <- bind_rows(
  fig3 |> transmute(experiment = facet, condition),
  fig4 |> transmute(experiment = "Hiscox", condition),
  fig5 |> transmute(experiment = "Berinsky", condition)
) |>
  filter(str_starts(condition, "CATE")) |>
  distinct(experiment)

# Verdicts ----
verdicts <- tribble(
  ~claim_id, ~holds, ~evidence,

  "majority_paid_dollars_or_points",
  entry(behavior, "surveycomptype_dollars", "lucid") +
    entry(behavior, "surveycomptype_points", "lucid") > 50,
  "share paid in dollars or points exceeds half",

  "lucid_closer_on_four_demographics",
  all(map_dbl(four_demographics, closer) > 0),
  "gender, education, age and income all favour Lucid",

  "education_lucid_closer_than_mturk", closer("education") > 0,
  "education distance favours Lucid",

  "income_lucid_between_anes_and_mturk",
  all(map_lgl(c("income_mean", "income_median"),
              ~ entry(demos, .x, "lucid") < entry(demos, .x, "anes2012") &
                entry(demos, .x, "lucid") > entry(demos, .x, "mturk"))),
  "mean and median income both sit between MTurk and the ANES 2012 face-to-face sample",

  "white_overrepresented_less_on_lucid",
  standardized("race_white", "lucid") > 0 & standardized("race_white", "mturk") > 0 &
    standardized("race_white", "lucid") < standardized("race_white", "mturk"),
  "both samples sit above the benchmark white share and Lucid by less",

  "mturk_overrepresents_southerners", standardized("region_south", "mturk") > 0,
  "MTurk's southern share sits below the benchmark, not above it",

  "lucid_closer_registration_and_turnout",
  closer("register") > 0 & closer("vote") > 0,
  "registration favours Lucid and turnout favours MTurk",

  "mturk_more_liberal",
  standardized("ideology", "mturk") < standardized("ideology", "lucid") &
    standardized("ideology", "mturk") < 0,
  "MTurk sits furthest below the benchmark on the conservatism scale",

  "interest_mturk_least_lucid_most",
  interest_samples[which.min(interest_means)] == "mturk" &
    interest_samples[which.max(interest_means)] == "lucid",
  "MTurk lowest and Lucid highest on political interest",

  "knowledge_mturk_above_anes_lucid_similar",
  entry(politics, "knowl_score", "mturk") > entry(politics, "knowl_score", "anes_panel") &
    abs(entry(politics, "knowl_score", "lucid") -
          entry(politics, "knowl_score", "anes_panel")) <
      abs(entry(politics, "knowl_score", "mturk") -
            entry(politics, "knowl_score", "anes_panel")),
  "MTurk above the ANES panel and Lucid nearer to it than MTurk is",

  "sig_closer_party_ideology_interest",
  all(map_dbl(c("party7", "ideology", "interest"), closer) > 0) &
    all(map_dbl(c("party7", "ideology", "interest"), p_archive) < 0.05) &
    closer("vote") < 0 & p_archive("vote") < 0.05,
  "three characteristics favour Lucid and turnout favours MTurk, all significant",

  "mturk_least_favors_senior_drugs",
  seniors_samples[which.min(seniors_means)] == "mturk" &
    seniors_samples[which.min(age_means)] == "mturk",
  "MTurk is lowest on support for senior drug benefits and youngest",

  "lucid_tracks_benchmarks_on_traits",
  all(map_lgl(c("conscientiousness", "emotionalstability"),
              ~ abs(entry(psych, .x, "lucid") - entry(psych, .x, "anes2012")) <
                abs(entry(psych, .x, "mturk") - entry(psych, .x, "anes2012")))),
  "Lucid nearer the ANES 2012 than MTurk on conscientiousness and stability",

  "traits_all_five_significantly_closer",
  all(map_dbl(trait_vars, closer) > 0) &
    all(distances$p_twotail[distances$variable %in% trait_vars] < 0.05),
  "under the two-tailed test the appendix describes, extraversion does not clear 0.05",

  "berinsky_no_mturk_estimate",
  !any(fig2$facet == "Berinsky" & fig2$Survey == "MTurk"),
  "the Berinsky facet carries no MTurk estimate",

  "welfare_cates_indistinguishable",
  all(map_lgl(split(filter(fig3, facet == "Welfare", str_starts(condition, "CATE")),
                    filter(fig3, facet == "Welfare", str_starts(condition, "CATE"))$Survey),
              overlap)),
  "the three race conditional effects overlap in both samples",

  "kamsimas_no_conditioning",
  all(with(filter(fig2, facet == "Kam and Simas", variable == "interaction",
                  Survey %in% c("Lucid", "Original")), li < 0 & ui > 0)),
  "the risk acceptance interaction spans zero in both samples",

  "hiscox_no_heterogeneity",
  all(map_lgl(group_split(filter(fig4, str_starts(condition, "CATE")), facet, Survey),
              overlap)),
  "conditional effects overlap within every frame by sample cell",

  "berinsky_only_democratic_correction",
  identical(
    z_between(filter(fig5, str_starts(condition, "CATE"))) |>
      filter(abs(z) > qnorm(0.975)) |>
      transmute(key = str_c(facet, " / ", condition)) |>
      pull(key),
    "Rumor + Democratic correction / CATE: Democrats"
  ),
  "the Democratic correction among Democrats is the only conditional effect that differs between samples",

  "most_cases_matched_sign_and_significance",
  sum(pairs$same_sign & pairs$sig_lucid == pairs$sig_original) > nrow(pairs) / 2,
  "more than half the Lucid estimates agree with the original on sign and significance",

  "appendix_two_tailed_method", FALSE,
  "the published p-value column is the archive's own expression, not the two-tailed test"
)

# Claims that state a count rather than a direction ----
# Two of these name a quantity the sentence does not define, so they carry a number and no
# verdict: the article does not say which policy items it means, nor what makes a result
# substantively different.
counted <- tribble(
  ~claim_id, ~value, ~holds, ~evidence,

  "heterogeneity_four_of_five", nrow(cate_experiments), NA,
  "experiments with at least one conditional average treatment effect",

  "policy_lucid_more_conservative", sum(lucid_more_conservative), NA,
  "policy items with an unambiguous direction on which Lucid polls more conservatively",

  "zero_cases_significant_opposite_sign",
  sum(pairs$sig_lucid & !pairs$same_sign), NA,
  "Lucid estimates that are significant with the opposite sign from the original",

  "one_substantively_different_result",
  n_distinct(pairs$facet[!pairs$same_sign | pairs$sig_lucid != pairs$sig_original]),
  NA, "experiments with at least one sign or significance mismatch against the original"
)

descriptive_claims <- bind_rows(
  verdicts |> transmute(claim_id, value = as.numeric(holds), holds, evidence),
  counted |> transmute(claim_id, value = as.numeric(value), holds, evidence)
)

stopifnot(!anyDuplicated(descriptive_claims$claim_id),
          !any(is.na(descriptive_claims$value)))

write_csv(descriptive_claims, file.path(out_dir, "text_descriptive_claims.csv"))

print(descriptive_claims, n = nrow(descriptive_claims))
