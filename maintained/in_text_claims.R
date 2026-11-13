# coppock_mcclellan_2019/maintained/in_text_claims.R
# Output: printed CLAIM lines and a CLAIM SUMMARY line; no files
# Depends on: helpers.R, excheckr, output/table_1_demographics.csv,
#   output/table_2_political.csv, output/table_3_psychological.csv,
#   output/table_4_welfare_ns.csv, output/table_5_asian_disease.csv,
#   output/table_6_kamsimas.csv, output/table_7_hiscox.csv,
#   output/table_8_health_rumors.csv, output/table_9_survey_behavior.csv,
#   output/text_in_text_claims.csv, output/appendix_table_1_distance_tests.csv,
#   output/appendix_table_1_distance_counts.csv,
#   output/appendix_table_2_kamsimas_probit.csv, output/figure_1_standardized_demos.csv,
#   output/figure_2_standardized_experiments.csv,
#   output/figure_3_cate_welfare_ad_ks.csv, output/figure_4_cate_hiscox.csv,
#   output/figure_5_cate_berinsky.csv, ground_truth/published_claims.csv,
#   errata_entries.csv
# Description: Every quantity the article and its online appendix state, beside the
#   sentence that states it, in the order a reader meets them.
#
#   This file recomputes. It reads the same maintained/output/ files the ground truth
#   reads and does its own selection, unit conversion and rounding, so the two instruments
#   arrive at each number by separate paths and a disagreement between them is a finding
#   rather than a coincidence. ground_truth/build_ground_truth.R runs this file
#   non-interactively, counts the CLAIM lines it printed, and stops if any of them
#   disagrees with its own value. It never reads the ground truth itself, and it never
#   refits: estimation happens once, in the analysis scripts, and only derivation happens
#   here.
#
#   It reads two files outside maintained/output/. ground_truth/published_claims.csv is
#   the extraction rather than the comparison: it says what the article prints and at
#   what precision. errata_entries.csv is the errata spine, which errata.qmd writes: it
#   says which printed numbers a published correction replaces, and with what.
#
#   Every claim prints one line, CLAIM <id> = <value> || [verdict] <label>, through
#   excheckr::claim(). That printed id is the only link between a block and the claim it
#   covers and it is load bearing: the gate reads this file as a program and matches on
#   what it printed. The "# covers:" comments are for a reader and nothing reads them,
#   because a comment is a second copy of the link that can go stale independently of the
#   code beside it.
#
#   The verdict is derived from the extraction and the errata spine, never typed here.
#   [match] means the article's number and this one agree; [corrected] means a quantity
#   erratum names the claim, the two disagree, and this value equals the corrected one.
#   [range] is declared at the call site for the bootstrap standard errors and p-values
#   of appendix Table 1, which are one draw of an unseeded bootstrap and are scored
#   against their resampling range in build_ground_truth.R. [derived] is declared where
#   the block computes something other than the article's own token in order to test it.
#   [shape] is a claim about shape, sign or count with no printed number, which prints
#   its own truth value: 1 when the estimates support the sentence and 0 when they do
#   not, with the evidence in the label. [hedged] is a descriptive claim whose number
#   does not agree. MISMATCH, STALE, DRIFT and MISSING fail the run.

source(here::here("maintained", "helpers.R"))
library(excheckr)

options(width = 200)

out <- function(f) read_csv(file.path(out_dir, f), show_col_types = FALSE)

demos <- out("table_1_demographics.csv")
politics <- out("table_2_political.csv")
psych <- out("table_3_psychological.csv")
welfare_ns <- out("table_4_welfare_ns.csv")
asian <- out("table_5_asian_disease.csv")
kamsimas <- out("table_6_kamsimas.csv")
hiscox <- out("table_7_hiscox.csv")
rumors <- out("table_8_health_rumors.csv")
behavior <- out("table_9_survey_behavior.csv")
text_values <- out("text_in_text_claims.csv")
distances <- out("appendix_table_1_distance_tests.csv")
counts <- out("appendix_table_1_distance_counts.csv")
probit <- out("appendix_table_2_kamsimas_probit.csv")
fig1 <- out("figure_1_standardized_demos.csv")
fig2 <- out("figure_2_standardized_experiments.csv")
fig3 <- out("figure_3_cate_welfare_ad_ks.csv")
fig4 <- out("figure_4_cate_hiscox.csv")
fig5 <- out("figure_5_cate_berinsky.csv")

# Every column is read as character: value_paper carries "0.100" and corrected_values
# carries "0", and a reader left to guess would destroy the precision both depend on.
published_claims <- read_csv(
  here::here("ground_truth", "published_claims.csv"),
  col_types = cols(.default = col_character())
)

errata <- read_csv(here::here("errata_entries.csv"),
                   col_types = cols(.default = col_character()))

# Entries 1 and 2 each name appendix_two_tailed_method beside the count they correct, with
# NA in its corrected_values position, because a statement of method has no number on any
# scale. excheckr takes exactly one corrected value for each claim a quantity erratum
# names, so the positions holding NA are dropped before the spine is registered. Every
# claim id and value that remains is passed through unchanged.
errata_values <- errata |>
  mutate(
    ids = str_split(claim_ids, ";"),
    values = str_split(corrected_values, ";"),
    valued = map(values, \(v) v != "NA"),
    claim_ids = if_else(is.na(corrected_values), claim_ids,
                        map2_chr(ids, valued, \(i, k) str_c(i[k], collapse = ";"))),
    corrected_values = if_else(is.na(corrected_values), corrected_values,
                               map2_chr(values, valued, \(v, k) str_c(v[k], collapse = ";")))
  ) |>
  select(-ids, -values, -valued)

# format = "id" is the CLAIM <id> = <value> || [verdict] <label> line
# build_ground_truth.R parses, and it must stay exactly that.
claim_start(published = published_claims, errata = errata_values, format = "id")

# A claim about shape, sign or count prints 1 or 0 for whether the estimates support it.
verdict <- function(id, holds, gloss) {
  stopifnot(length(holds) == 1, is.logical(holds), !is.na(holds))
  claim(id, as.numeric(holds), gloss, digits = 0)
}

# Accessors ----
# Each stops unless the filter selects exactly one row, so a claim cannot quietly read a
# row that is not there and print a plausible number from the wrong place.

# The descriptive tables print "52.15 (0.85)", the mean then its standard error, and the
# article quotes the mean alone. Dollar signs and thousands separators are typography.
cell <- function(tab, var, col) {
  entry <- tab[[col]][tab$variable == var]
  stopifnot(length(entry) == 1)
  as.numeric(str_remove_all(str_extract(entry, "^[$]?-?[0-9,.]+"), "[$,]"))
}

dist_row <- function(var) {
  row <- distances[distances$variable == var, ]
  stopifnot(nrow(row) == 1)
  row
}

fitted_n <- function(tab, key, value) {
  n <- unique(tab$nobs[tab[[key]] == value])
  stopifnot(length(n) == 1)
  n
}

text_value <- function(label) {
  entry <- text_values$value_pipeline[text_values$claim == label]
  stopifnot(length(entry) == 1)
  as.numeric(str_remove_all(str_extract(entry, "^-?[0-9,.]+"), ","))
}

# Pairs a Lucid estimate with the estimate from the study it replicates, so that a claim
# about agreement between the two is a comparison of two rows rather than an assertion.
replication_pairs <- function() {
  fig2 |>
    filter(Survey %in% c("Lucid", "Original")) |>
    select(facet, variable, Survey, coef, se, li, ui) |>
    pivot_wider(names_from = Survey, values_from = c(coef, se, li, ui)) |>
    mutate(
      sign_agrees = sign(coef_Lucid) == sign(coef_Original),
      lucid_significant = li_Lucid > 0 | ui_Lucid < 0,
      original_significant = li_Original > 0 | ui_Original < 0,
      z_difference = (coef_Lucid - coef_Original) / sqrt(se_Lucid^2 + se_Original^2)
    )
}

# Confidence intervals in these tables overlap unless the estimates they belong to are far
# apart, so mutual overlap is a conservative reading of "statistically indistinguishable":
# it can call two estimates indistinguishable that a difference test would separate, and
# never the reverse.
intervals_overlap <- function(lower, upper) max(lower) <= min(upper)

# Introduction ----

# "In our empirical section, we replicate five survey experiments that were originally
#  conducted on other samples."
# covers: intro_five_experiments
claim("intro_five_experiments", n_distinct(fig2$facet),
      "experiments summarised in Figure 2")

# Our sample ----

# "As we only have a single sample of 3504 subjects obtained in March of 2016, we cannot
#  empirically assess the extent of overtime variation."
# covers: sample_lucid_n
claim("sample_lucid_n", cell(demos, "n", "lucid"), "Lucid respondents")

# "Respondents report taking an average of 4.28 surveys per month. However, 98% of
#  respondents report taking fewer than one survey per day; the average number of surveys
#  per month among these respondents is 2.43."
# covers: surveys_per_month_mean, share_under_one_survey_a_day, surveys_per_month_trimmed
claim("surveys_per_month_mean", cell(behavior, "numsurvey", "lucid"),
      "mean surveys per month, Lucid")
claim("share_under_one_survey_a_day",
      text_value("Percent taking fewer than one survey per day"),
      "per cent reporting fewer than one survey a day")
claim("surveys_per_month_trimmed", cell(behavior, "numsurvey_trim", "lucid"),
      "mean surveys per month among those taking fewer than one a day")

# "The vast majority of subjects (94%) take surveys at home, and the majority are
#  compensated directly in dollars or in some form of points program."
# covers: share_surveys_at_home, majority_paid_dollars_or_points
claim("share_surveys_at_home", cell(behavior, "surveylocation_home", "lucid"),
      "per cent taking surveys at home")

paid_dollars_or_points <- cell(behavior, "surveycomptype_dollars", "lucid") +
  cell(behavior, "surveycomptype_points", "lucid")

verdict("majority_paid_dollars_or_points", paid_dollars_or_points > 50,
        str_glue("{sprintf('%.1f', paid_dollars_or_points)} per cent are paid in dollars ",
                 "or points, which is a majority"))

# "Unconditionally, the average compensation amount that subjects reported expecting was
#  US$5.01, but if we trim off responses that are implausible (greater than US$20.00), we
#  obtain the more reasonable figure of US$1.16."
# covers: compensation_mean, compensation_mean_trimmed
claim("compensation_mean", cell(behavior, "surveycompamount", "lucid"),
      "mean expected compensation in dollars")
claim("compensation_mean_trimmed", cell(behavior, "surveycompamount_trim", "lucid"),
      "mean expected compensation in dollars, trimmed at 20 dollars")

# Baseline characteristics ----

# "Figure 1 presents standardized demographic means on Lucid, MTurk, and the 2012 American
#  National Election Study (ANES), where we standardize by the ANES 2012 mean and standard
#  deviation."
# covers: figure_1_standardization
claim("figure_1_standardization", max(abs(fig1$mean[fig1$survey == "anes2012"])),
      "largest standardized ANES 2012 mean in Figure 1, zero if the ANES 2012 is the standardizing sample",
      digits = 3)

# "In terms of gender, education, age, and income, the Lucid sample comes closer to the
#  ANES 2012 benchmarks than the MTurk sample does."
# covers: lucid_closer_on_four_demographics
four_demographics <- c("female", "education", "age", "income")

verdict("lucid_closer_on_four_demographics",
        all(distances$lucid_is_closer[distances$variable %in% four_demographics] > 0),
        str_glue("|MTurk - ANES| - |Lucid - ANES| is positive on all four of gender, ",
                 "education, age and income; the smallest is ",
                 "{sprintf('%.3f', min(distances$lucid_is_closer[distances$variable %in% four_demographics]))}"))

# "The Lucid sample was 52% female - much closer to the Census value of 50.8% than the 60%
#  female sample collect on MTurk."
# covers: female_lucid, female_mturk
claim("female_lucid", cell(demos, "female", "lucid"), "per cent female, Lucid")
claim("female_mturk", cell(demos, "female", "mturk"), "per cent female, MTurk")

# "The mean number of years of education on Lucid (14.2) is higher than the approximately
#  13.5 years recorded by the ANES survey, but is closer than MTurk sample estimates."
# covers: education_lucid, education_anes, education_lucid_closer_than_mturk
claim("education_lucid", cell(demos, "education", "lucid"),
      "mean years of education, Lucid")
claim("education_anes", cell(demos, "education", "anes"),
      "mean years of education, ANES")
verdict("education_lucid_closer_than_mturk",
        dist_row("education")$lucid_is_closer > 0,
        str_glue("Lucid sits {sprintf('%.3f', dist_row('education')$lucid_is_closer)} ",
                 "standard deviations closer to the ANES 2012 on education than MTurk does"))

# "Both mean and median incomes are lower on Lucid than among the face-to-face sample, but
#  are higher than in the MTurk sample."
# covers: income_lucid_between_anes_and_mturk
income_between <- c("income_mean", "income_median") |>
  map_lgl(~ cell(demos, .x, "lucid") < cell(demos, .x, "anes2012") &
            cell(demos, .x, "lucid") > cell(demos, .x, "mturk"))

verdict("income_lucid_between_anes_and_mturk", all(income_between),
        str_glue("Lucid mean income {sprintf('%.0f', cell(demos, 'income_mean', 'lucid'))} ",
                 "and median {sprintf('%.0f', cell(demos, 'income_median', 'lucid'))} both ",
                 "sit between MTurk and the ANES 2012 face-to-face sample"))

# "Both of the Internet samples overrepresent whites relative to non-whites, but this
#  distortion is smaller on Lucid."
# covers: white_overrepresented_less_on_lucid
white_lucid <- cell(demos, "race_white", "lucid") - cell(demos, "race_white", "anes2012")
white_mturk <- cell(demos, "race_white", "mturk") - cell(demos, "race_white", "anes2012")

verdict("white_overrepresented_less_on_lucid",
        white_lucid > 0 & white_mturk > 0 & abs(white_lucid) < abs(white_mturk),
        str_glue("both samples sit above the ANES 2012 white share, Lucid by ",
                 "{sprintf('%.1f', white_lucid)} points and MTurk by ",
                 "{sprintf('%.1f', white_mturk)}"))

# "The regional balance on Lucid comes very close to the 2012 ANES, whereas the MTurk
#  sample appears to overrepresent southerners."
# covers: mturk_overrepresents_southerners
south_mturk <- cell(demos, "region_south", "mturk") - cell(demos, "region_south", "anes2012")

verdict("mturk_overrepresents_southerners", south_mturk > 0,
        str_glue("MTurk's southern share is {sprintf('%.1f', south_mturk)} points ",
                 "from the ANES 2012 benchmark, so southerners are under-represented ",
                 "rather than over-represented"))

# "Out of the 11 demographic variables that are measured for both Lucid and MTurk, the
#  Lucid mean is closer to the ANES mean in nine instances, five of which are
#  statistically significant."
# covers: demographic_variables_tested, demographic_lucid_closer,
#         demographic_significantly_closer
demographic_vars <- c("female", "education", "age", "income", "race_white", "race_black",
                      "race_hispanic", "region_northeast", "region_midwest",
                      "region_south", "region_west")
demographic_rows <- filter(distances, variable %in% demographic_vars)

claim("demographic_variables_tested", nrow(demographic_rows),
      "demographic variables measured on both Lucid and MTurk")
claim("demographic_lucid_closer", sum(demographic_rows$lucid_is_closer > 0),
      "demographic variables on which Lucid sits closer to the ANES 2012")
claim("demographic_significantly_closer",
      sum(demographic_rows$lucid_is_closer > 0 & demographic_rows$p_archive < 0.05),
      "of those that are significant at 0.05 under the p-value the appendix table prints")

# "Voter registration and turnout seem to vary somewhat across samples, with the Lucid
#  sample corresponding more closely to the 2012 ANES baseline for voter registration and
#  voter turnout."
# covers: lucid_closer_registration_and_turnout
verdict("lucid_closer_registration_and_turnout",
        dist_row("register")$lucid_is_closer > 0 & dist_row("vote")$lucid_is_closer > 0,
        str_glue("registration favours Lucid at ",
                 "{sprintf('%.3f', dist_row('register')$lucid_is_closer)} and turnout ",
                 "favours MTurk at {sprintf('%.3f', dist_row('vote')$lucid_is_closer)}, ",
                 "which is what appendix Table 1 prints"))

# "Political party affiliation seems to track closely across samples, though the Lucid mean
#  of 3.7 is identical to that collected in the 2012 ANES, while the MTurk average is
#  slightly lower at 3.5."
# covers: party7_lucid, party7_anes2012, party7_mturk
claim("party7_lucid", cell(politics, "party7", "lucid"), "mean party identification, Lucid")
claim("party7_anes2012", cell(politics, "party7", "anes2012"),
      "mean party identification, ANES 2012")
claim("party7_mturk", cell(politics, "party7", "mturk"), "mean party identification, MTurk")

# "We see important variation with regard to respondents' ideologies: respondents on MTurk
#  are markedly more liberal than respondents found on Lucid or the ANES."
# covers: mturk_more_liberal
verdict("mturk_more_liberal",
        cell(politics, "ideology", "mturk") < cell(politics, "ideology", "lucid") &
          cell(politics, "ideology", "mturk") < cell(politics, "ideology", "anes2012"),
        str_glue("on the seven point scale, where higher is more conservative, MTurk is ",
                 "at {sprintf('%.2f', cell(politics, 'ideology', 'mturk'))} against Lucid ",
                 "{sprintf('%.2f', cell(politics, 'ideology', 'lucid'))} and the ANES 2012 ",
                 "{sprintf('%.2f', cell(politics, 'ideology', 'anes2012'))}"))

# "On average, MTurk respondents have the least interest in politics, while Lucid
#  respondents have the most."
# covers: interest_mturk_least_lucid_most
interest_samples <- c("lucid", "mturk", "anes_panel", "anes", "anes2012")
interest_means <- map_dbl(interest_samples, ~ cell(politics, "interest", .x))
names(interest_means) <- interest_samples

verdict("interest_mturk_least_lucid_most",
        which.min(interest_means) == which(interest_samples == "mturk") &
          which.max(interest_means) == which(interest_samples == "lucid"),
        str_glue("MTurk is lowest at {sprintf('%.2f', interest_means[['mturk']])} and Lucid ",
                 "highest at {sprintf('%.2f', interest_means[['lucid']])} across the five ",
                 "samples the political table carries"))

# "The difference between Lucid and MTurk is large, about 1.2 points on the five-point
#  political interest scale."
# covers: interest_lucid_minus_mturk
claim("interest_lucid_minus_mturk",
      cell(politics, "interest", "lucid") - cell(politics, "interest", "mturk"),
      "Lucid minus MTurk mean political interest")

# "MTurk respondents scored higher on political knowledge then did respondents on the ANES
#  panel, while Lucid respondents scored nearly identically."
# covers: knowledge_mturk_above_anes_lucid_similar
knowledge_gap_mturk <- cell(politics, "knowl_score", "mturk") -
  cell(politics, "knowl_score", "anes_panel")
knowledge_gap_lucid <- cell(politics, "knowl_score", "lucid") -
  cell(politics, "knowl_score", "anes_panel")

verdict("knowledge_mturk_above_anes_lucid_similar",
        knowledge_gap_mturk > 0 & abs(knowledge_gap_lucid) < abs(knowledge_gap_mturk),
        str_glue("MTurk sits {sprintf('%.1f', knowledge_gap_mturk)} points above the ANES ",
                 "panel and Lucid {sprintf('%.1f', knowledge_gap_lucid)} points from it"))

# "Lucid is significantly closer to the ANES 2012 on party identification, ideology, and
#  political interest, while MTurk is significantly closer for voter turnout."
# covers: sig_closer_party_ideology_interest
lucid_closer_sig <- c("party7", "ideology", "interest") |>
  map_lgl(~ dist_row(.x)$lucid_is_closer > 0 & dist_row(.x)$p_archive < 0.05)

verdict("sig_closer_party_ideology_interest",
        all(lucid_closer_sig) &
          dist_row("vote")$lucid_is_closer < 0 & dist_row("vote")$p_archive < 0.05,
        "party identification, ideology and interest favour Lucid and turnout favours MTurk, all four significant at 0.05 under the appendix table's p-value")

# "These estimates are generally consistent across samples, with Lucid polling slightly
#  more conservatively than MTurk."
# covers: policy_lucid_more_conservative
# The four policy items whose conservative direction is not in doubt. The two tax items
# are left out: a higher rate on incomes above 200,000 dollars and a higher rate on
# incomes below it do not point the same way, and the sentence does not say which items
# it means, so no verdict is returned for this claim.
conservative_direction <- c(seniors = -1, healthcare = -1, immigration = -1, gaymarriage = 1)

lucid_more_conservative <- imap_lgl(
  conservative_direction,
  ~ .x * (cell(politics, .y, "lucid") - cell(politics, .y, "mturk")) > 0
)

claim("policy_lucid_more_conservative", sum(lucid_more_conservative),
      "of the four policy items with an unambiguous conservative direction on which Lucid polls more conservatively than MTurk",
      digits = 0)

# "MTurk respondents are the least likely to favor prescription drug benefits for seniors,
#  possibly because MTurk respondents are younger on average."
# covers: mturk_least_favors_senior_drugs
seniors_samples <- c("lucid", "mturk", "anes_panel", "anes")
seniors_means <- map_dbl(seniors_samples, ~ cell(politics, "seniors", .x))
age_means <- map_dbl(seniors_samples, ~ cell(demos, "age", .x))

verdict("mturk_least_favors_senior_drugs",
        which.min(seniors_means) == which(seniors_samples == "mturk") &
          which.min(age_means) == which(seniors_samples == "mturk"),
        str_glue("MTurk support is lowest at {sprintf('%.1f', min(seniors_means))} per cent ",
                 "and its mean age is lowest at {sprintf('%.1f', min(age_means))} years"))

# "The Lucid sample tracks very well with the Cooperative Congressional Election Study
#  (CCES), Cooperative Campaign Analysis Project (CCAP), and ANES 2012 on all five
#  personality traits, perhaps slightly outperforming the MTurk sample on Conscientiousness
#  and Stability."
# covers: lucid_tracks_benchmarks_on_traits
outperformed <- c("conscientiousness", "emotionalstability") |>
  map_lgl(~ abs(cell(psych, .x, "lucid") - cell(psych, .x, "anes2012")) <
            abs(cell(psych, .x, "mturk") - cell(psych, .x, "anes2012")))

verdict("lucid_tracks_benchmarks_on_traits", all(outperformed),
        str_glue("Lucid sits closer to the ANES 2012 than MTurk on conscientiousness ",
                 "({sprintf('%.2f', cell(psych, 'conscientiousness', 'lucid'))} against ",
                 "{sprintf('%.2f', cell(psych, 'conscientiousness', 'mturk'))}, benchmark ",
                 "{sprintf('%.2f', cell(psych, 'conscientiousness', 'anes2012'))}) and on ",
                 "stability"))

# "Formal hypothesis tests demonstrate that Lucid is significantly closer to the ANES 2012
#  than MTurk on all five traits."
# covers: traits_all_five_significantly_closer
trait_vars <- c("extraversion", "agreeableness", "conscientiousness",
                "emotionalstability", "opennesstoexperiences")
trait_rows <- filter(distances, variable %in% trait_vars)
traits_significant <- sum(trait_rows$lucid_is_closer > 0 & trait_rows$p_twotail < 0.05)

# Errata entry 1 corrects this sentence and stores its corrected value, 0, on the claim's
# truth-value scale. The sentence asserts that the statement holds, which is 1 on that
# scale, and stating so here is what lets the claim score against the erratum: with no
# published value at all, excheckr scores a claim shape before it consults the spine.
claim("traits_all_five_significantly_closer",
      as.numeric(traits_significant == length(trait_vars)),
      str_glue("{traits_significant} of the five traits are significantly closer under ",
               "the two-tailed test the appendix says it used; extraversion is not, at ",
               "z = {sprintf('%.2f', dist_row('extraversion')$z)} and p = ",
               "{sprintf('%.3f', dist_row('extraversion')$p_twotail)}. All five clear ",
               "0.05 under the p-value the published table actually carries"),
      published = "1", digits = 0)

# Experiments ----

# "In all cases, we estimate HC2 robust standard errors to construct 95% confidence
#  intervals and conduct hypothesis tests."
# covers: hc2_ci_level
half_width_in_ses <- with(asian, (conf.high - estimate) / std.error)

claim("hc2_ci_level", 100 * (2 * pnorm(mean(half_width_in_ses)) - 1),
      "confidence level implied by the half widths of the Asian Disease intervals, under a normal approximation")

# "The Berinsky facet does not include an MTurk estimate since it has not been previously
#  replicated on an MTurk sample."
# covers: berinsky_no_mturk_estimate
verdict("berinsky_no_mturk_estimate",
        !any(fig2$facet == "Berinsky" & fig2$Survey == "MTurk"),
        str_glue("the Berinsky facet of Figure 2 carries ",
                 "{sum(fig2$facet == 'Berinsky')} estimates and none of them is MTurk"))

# "The study employed a 2 x 4 design. The first factor is the Expert treatment ... The
#  second factor is the valence frame, which highlights positive, negative, or both
#  positive and negative impacts of free trade."
# covers: hiscox_expert_levels, hiscox_valence_levels
hiscox_terms <- unique(hiscox$term[hiscox$term != "(Intercept)"])

claim("hiscox_expert_levels", 1 + sum(str_detect(hiscox_terms, "expert$")),
      "levels of the expert factor, the omitted level plus one indicator")
claim("hiscox_valence_levels", 1 + sum(str_detect(hiscox_terms, "valence")),
      "levels of the valence factor, the omitted control plus three indicators")

# "On a -1 to 1 scale (with 0 indicating the respondent was "not sure"), average levels of
#  belief were -0.17 on Lucid, compared with -0.19 in the original."
# covers: rumor_lucid_control_mean, rumor_original_control_mean
control_mean <- function(survey_id) {
  value <- rumors$estimate[rumors$survey == survey_id & rumors$term == "(Intercept)"]
  stopifnot(length(value) == 1)
  value
}

claim("rumor_lucid_control_mean", control_mean("lucid"),
      "mean death panel belief in the Lucid control group")
claim("rumor_original_control_mean", control_mean("ssi"),
      "mean death panel belief in the original control group")

# Treatment effect heterogeneity ----

# "In this section, we assess treatment effect heterogeneity in four of the five
#  experiments replicated above."
# covers: heterogeneity_four_of_five
cate_experiments <- bind_rows(
  fig3 |> transmute(experiment = facet, condition),
  fig4 |> transmute(experiment = "Hiscox", condition),
  fig5 |> transmute(experiment = "Berinsky", condition)
) |>
  filter(str_starts(condition, "CATE")) |>
  distinct(experiment)

claim("heterogeneity_four_of_five", nrow(cate_experiments),
      "experiments whose heterogeneity figures carry at least one conditional average treatment effect")

# "We assess whether the treatment effect of receiving the "assistance to the poor" versus
#  "welfare" phrasing varies among white, black, and Latino respondents, among both the
#  Lucid sample and respondents in the 2016 GSS."
# covers: welfare_gss_year
gss_years <- welfare_ns$survey |>
  str_subset("^GSS") |>
  str_remove("^GSS") |>
  as.numeric()
gss_years <- if_else(gss_years < 50, 2000 + gss_years, 1900 + gss_years)

# The deposit holds no 2016 survey, so the block prints the most recent year it does hold
# and declares that it is testing the sentence's token rather than reproducing it.
claim("welfare_gss_year", max(gss_years),
      "most recent General Social Survey in the deposited welfare data, the baseline the article's own Experiment 1 section names",
      expect = "derived")

# "Both samples generally exhibit low treatment effect heterogeneity, with CATEs among
#  white, black, and Latino respondents being statistically indistinguishable from one
#  another."
# covers: welfare_cates_indistinguishable
welfare_cates <- fig3 |>
  filter(facet == "Welfare", str_starts(condition, "CATE"))

verdict("welfare_cates_indistinguishable",
        all(map_lgl(split(welfare_cates, welfare_cates$Survey),
                    ~ intervals_overlap(.x$li, .x$ui))),
        "the three race conditional effects have mutually overlapping intervals in both the Lucid and the original sample")

# "In neither sample do we see a significant conditioning effect for risk assessment -
#  both the original sample and Lucid sample are able to replicate estimates of (the lack
#  of) heterogeneous treatment effects."
# covers: kamsimas_no_conditioning
interaction_rows <- filter(fig2, facet == "Kam and Simas", variable == "interaction",
                           Survey %in% c("Lucid", "Original"))

verdict("kamsimas_no_conditioning",
        all(interaction_rows$li < 0 & interaction_rows$ui > 0),
        str_glue("the risk acceptance by mortality frame interaction spans zero in both ",
                 "samples, at {str_c(sprintf('%.2f', interaction_rows$coef), collapse = ' and ')}"))

# "Across both the original sample and Lucid sample, we see no evidence of heterogeneous
#  treatment effects for any of the possible treatment conditions."
# covers: hiscox_no_heterogeneity
hiscox_cates <- fig4 |>
  filter(str_starts(condition, "CATE")) |>
  group_split(facet, Survey)

verdict("hiscox_no_heterogeneity",
        all(map_lgl(hiscox_cates, ~ intervals_overlap(.x$li, .x$ui))),
        str_glue("the conditional effects within each of the ",
                 "{length(hiscox_cates)} frame by sample cells have mutually overlapping intervals"))

# "here we see that the CATEs are statistically differentiable for only Democrats
#  receiving the Democratic correction to the healthcare rumor."
# covers: berinsky_only_democratic_correction
berinsky_differences <- fig5 |>
  filter(str_starts(condition, "CATE")) |>
  select(facet, condition, Survey, coef, se) |>
  pivot_wider(names_from = Survey, values_from = c(coef, se)) |>
  mutate(z = (coef_Lucid - coef_Original) / sqrt(se_Lucid^2 + se_Original^2))

differentiable <- filter(berinsky_differences, abs(z) > qnorm(0.975))

verdict("berinsky_only_democratic_correction",
        nrow(differentiable) == 1 &&
          differentiable$facet == "Rumor + Democratic correction" &&
          differentiable$condition == "CATE: Democrats",
        str_glue("of the {nrow(berinsky_differences)} conditional effects in Figure 5, ",
                 "{nrow(differentiable)} differs between Lucid and the original sample at ",
                 "0.05, and it is {str_c(differentiable$condition, ', ', differentiable$facet)}"))

# Discussion ----

# "In most cases, our estimates matched the original in terms of sign and significance."
# covers: most_cases_matched_sign_and_significance
pairs <- replication_pairs()
matched <- with(pairs, sign_agrees & lucid_significant == original_significant)

verdict("most_cases_matched_sign_and_significance", sum(matched) > nrow(pairs) / 2,
        str_glue("{sum(matched)} of the {nrow(pairs)} Lucid estimates agree with the ",
                 "original on both sign and significance"))

# "In zero cases did we recover an estimate that was statistically significant and had the
#  opposite sign from the original."
# covers: zero_cases_significant_opposite_sign
claim("zero_cases_significant_opposite_sign",
      sum(pairs$lucid_significant & !pairs$sign_agrees),
      "Lucid estimates that are significant and carry the opposite sign from the original")

# "Among our five experiments, we have one instance of the Lucid sample producing
#  substantively different results compared to the original study."
# covers: one_substantively_different_result
mismatched_experiments <- pairs |>
  filter(!sign_agrees | lucid_significant != original_significant) |>
  distinct(facet)

claim("one_substantively_different_result", nrow(mismatched_experiments),
      str_glue("experiments carrying at least one Lucid estimate that differs from the ",
               "original in sign or significance, namely ",
               "{str_c(mismatched_experiments$facet, collapse = ' and ')}; the article ",
               "does not say what makes a result substantively different"),
      digits = 0)

# Appendix 1: formal tests of demographic differences ----

# "Because no formula for the standard error of this procedure is available, we use the
#  nonparametric bootstrap to estimate sampling variability and we obtain two-tailed
#  p-values under a normal approximation."
# covers: appendix_two_tailed_method
published_a1 <- published_claims |>
  filter(str_starts(claim_id, "a1_")) |>
  transmute(
    quantity = str_extract(claim_id, "(?<=^a1_)[a-z]+"),
    variable = str_remove(claim_id, "^a1_[a-z]+_"),
    value = as.numeric(value_paper)
  ) |>
  pivot_wider(names_from = quantity, values_from = value)

published_a1 <- published_a1 |>
  mutate(
    z = distance / se,
    implied_twotail = 2 * pnorm(-abs(z)),
    implied_archive = pnorm(2 * (1 - abs(z)))
  )

max_gap_twotail <- max(abs(round(published_a1$implied_twotail, 3) - published_a1$p))
max_gap_archive <- max(abs(round(published_a1$implied_archive, 3) - published_a1$p))

verdict("appendix_two_tailed_method", max_gap_twotail < max_gap_archive,
        str_glue("recomputing each p-value from the distance and standard error the ",
                 "table itself prints, the published column sits at most ",
                 "{sprintf('%.3f', max_gap_archive)} from pnorm(2 * (1 - |z|)) and at most ",
                 "{sprintf('%.3f', max_gap_twotail)} from the two-tailed test, so the ",
                 "column is not the two-tailed test the text describes"))

# "Out of 21 opportunities, Lucid is closer to the ANES 18 times, 14 of which are
#  significant. By contrast, MTurk is closer in only 3 instances, and significant in only
#  one (voter turnout)."
# covers: appendix_opportunities, appendix_lucid_closer, appendix_lucid_closer_significant,
#         appendix_mturk_closer, appendix_mturk_closer_significant
claim("appendix_opportunities", nrow(distances), "characteristics tested")
claim("appendix_lucid_closer", sum(distances$lucid_is_closer > 0),
      "characteristics on which Lucid sits closer to the ANES 2012")
claim("appendix_lucid_closer_significant",
      sum(distances$lucid_is_closer > 0 & distances$p_archive < 0.05),
      "of those that are significant under the p-value the published table carries")
claim("appendix_mturk_closer", sum(distances$lucid_is_closer < 0),
      "characteristics on which MTurk sits closer")
claim("appendix_mturk_closer_significant",
      sum(distances$lucid_is_closer < 0 & distances$p_archive < 0.05),
      "of those that are significant under the p-value the published table carries")

# The distance script writes these five counts too. Recomputing them here from the table
# of tests it also writes is the cheapest available check that the two files agree.
stopifnot(
  counts$n_variables == nrow(distances),
  counts$n_lucid_closer == sum(distances$lucid_is_closer > 0),
  counts$n_mturk_closer == sum(distances$lucid_is_closer < 0),
  counts$n_sig_closer_archive == sum(distances$lucid_is_closer > 0 & distances$p_archive < 0.05),
  counts$n_sig_farther_archive == sum(distances$lucid_is_closer < 0 & distances$p_archive < 0.05)
)

# Appendix Table 1 ----
# The table's own 63 cells. No sentence is quoted: a verbatim quote is what makes a prose
# claim locatable, and a table cell is located by its row and column.

a1_cells <- distances |>
  transmute(variable,
            distance = lucid_is_closer,
            se,
            p = p_archive) |>
  pivot_longer(c(distance, se, p), names_to = "quantity", values_to = "value")

# The distances involve no resampling and are compared digit for digit. The standard
# errors and the p-values computed from them are one draw of an unseeded 100-resample
# bootstrap, so they are declared range here and scored against the spread of that
# procedure in build_ground_truth.R.
pwalk(a1_cells, function(variable, quantity, value) {
  label <- c(distance = "distance", se = "bootstrap standard error", p = "p-value")
  claim(str_c("a1_", quantity, "_", variable), value,
        str_c("appendix Table 1, ", label[[quantity]], ", ", variable),
        expect = if_else(quantity == "distance", "compare", "range"))
})

# Appendix Table 2 ----
# The published standard errors are the HC2 robust ones the table's own note describes.
# The three adjusted models also carry demographic covariates, which the published table
# suppresses behind a "Covariates: Yes" row, so only the four printed terms are claims.

term_key <- c("mortalityfirst" = "mf", "ramean" = "ra",
              "mortalityfirst:ramean" = "raxmf", "(Intercept)" = "int")

a2_cells <- probit |>
  filter(term %in% names(term_key)) |>
  transmute(model, term_id = unname(term_key[term]),
            coef = estimate, se = robust.std.error) |>
  pivot_longer(c(coef, se), names_to = "quantity", values_to = "value")

pwalk(a2_cells, function(model, term_id, quantity, value) {
  claim(str_c("a2_", quantity, "_", model, "_", term_id), value,
        str_c("appendix Table 2, ", quantity, ", ", model, ", ", term_id))
})

a2_fit <- probit |>
  distinct(model, nobs, logLik, AIC) |>
  pivot_longer(c(nobs, logLik, AIC), names_to = "quantity", values_to = "value")

pwalk(a2_fit, function(model, quantity, value) {
  claim(str_c("a2_", str_to_lower(quantity), "_", model), value,
        str_c("appendix Table 2, ", quantity, ", ", model))
})

# Appendix 2: study manifest ----
# Every study description opens with a stated sample size. These are fitted samples:
# subjects with a missing or don't know outcome are dropped, following the original
# authors, as the article says.

manifest <- tribble(
  ~claim_id,                    ~value,                                        ~gloss,
  "manifest_welfare_gss84_n",   welfare_ns$n[welfare_ns$survey == "GSS84"],    "welfare, GSS 1984",
  "manifest_welfare_gss14_n",   welfare_ns$n[welfare_ns$survey == "GSS14"],    "welfare, GSS 2014",
  "manifest_welfare_lucid_n",   welfare_ns$n[welfare_ns$survey == "lucid"],    "welfare, Lucid",
  "manifest_welfare_mturk_n",   welfare_ns$n[welfare_ns$survey == "mturk"],    "welfare, MTurk",
  "manifest_ad_original_n",     fitted_n(asian, "survey", "original"),         "Asian Disease, original",
  "manifest_ad_lucid_n",        fitted_n(asian, "survey", "lucid"),            "Asian Disease, Lucid",
  "manifest_ks_original_n",     fitted_n(kamsimas, "model", "kam_base"),       "Kam and Simas, original",
  "manifest_ks_lucid_n",        fitted_n(kamsimas, "model", "lucid_base"),     "Kam and Simas, Lucid",
  "manifest_ks_mturk_n",        fitted_n(kamsimas, "model", "mturk_base"),     "Kam and Simas, MTurk",
  "manifest_hiscox_original_n", fitted_n(hiscox, "survey", "hiscox"),          "Hiscox, original",
  "manifest_hiscox_lucid_n",    fitted_n(hiscox, "survey", "lucid"),           "Hiscox, Lucid",
  "manifest_hiscox_gfk_n",      fitted_n(hiscox, "survey", "tess"),            "Hiscox, GfK",
  "manifest_hiscox_mturk_n",    fitted_n(hiscox, "survey", "mturk"),           "Hiscox, MTurk",
  "manifest_rumors_original_n", fitted_n(rumors, "survey", "ssi"),             "healthcare rumors, original",
  "manifest_rumors_lucid_n",    fitted_n(rumors, "survey", "lucid"),           "healthcare rumors, Lucid"
)

pwalk(manifest, function(claim_id, value, gloss) {
  claim(claim_id, value, str_c("respondents in the fitted sample, ", gloss))
})

# Gates ----
# assert_claims() stops on any MISMATCH, STALE, DRIFT or MISSING, on a quantity erratum
# whose claim did not score corrected, and on any difference between the claims printed
# here and those the extraction marks needs_block. claim_summary() then prints the verdict
# counts, so the claims this file declines to assert are counted rather than merely allowed.
assert_claims()
invisible(claim_summary())
