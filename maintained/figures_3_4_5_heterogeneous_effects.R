# coppock_mcclellan_2019/maintained/figures_3_4_5_heterogeneous_effects.R
# Output: output/figure_3_cate_welfare_ad_ks.pdf, .png and .csv
#         output/figure_4_cate_hiscox.pdf, .png and .csv
#         output/figure_5_cate_berinsky.pdf, .png and .csv
# Depends on: helpers.R,
#   original/ReplicationArchive/standardizedExperimentsHeterogeneousEffects.RData
# Description: Figures 3, 4 and 5, conditional average treatment effects, the archive's
#   script 11. The three figures are one script because they are three subsets of a
#   single data file drawn with a single specification.
#   The archive's Hiscox panel sets scale_shape_manual and scale_color_manual twice and
#   geom_vline twice; ggplot2 keeps the later scale and warns. Only one of each is kept
#   here, which is what the archive's figure actually shows.

source(here::here("maintained", "helpers.R"))

load(file.path(data_dir, "standardizedExperimentsHeterogeneousEffects.RData"))

make_cate_plot <- function(dat, title_str) {
  ggplot(dat, aes(x = coef, y = condition, group = Survey,
                  color = Survey, shape = Survey)) +
    geom_point(position = position_dodge(width = 0.5)) +
    geom_linerange(aes(xmin = li, xmax = ui),
                   position = position_dodge(width = 0.5)) +
    geom_vline(xintercept = 0, linetype = "dashed", alpha = 0.5) +
    scale_shape_manual(values = c(16, 15)) +
    scale_color_manual(values = c("#0099CC", "#CC3333")) +
    facet_grid(facet_f ~ ., scales = "free", space = "free") +
    theme_bw() +
    theme(
      axis.title = element_blank(),
      legend.position = "bottom",
      legend.title = element_blank(),
      strip.background = element_blank()
    ) +
    ggtitle(title_str)
}

panels <- tribble(
  ~name, ~facets, ~title,
  "figure_3_cate_welfare_ad_ks",
  c("Welfare", "Asian Disease", "Kam and Simas"),
  "Conditional Average Treatment Effects For Welfare, Asian Disease, and Kam and Simas Replications",
  "figure_4_cate_hiscox",
  c("Expert", "Positive frame", "Negative frame", "Both frames"),
  "Conditional Average Treatment Effects For Hiscox Free Trade Experiment",
  "figure_5_cate_berinsky",
  c("Rumor only", "Rumor + Nonpartisan correction",
    "Rumor + Republican correction", "Rumor + Democratic correction"),
  "Conditional Average Treatment Effects For Berinsky Health Care Rumors Experiment"
)

walk2(panels$name, seq_len(nrow(panels)), function(nm, i) {
  gg_df <- filter(standardizedExperiments, facet %in% panels$facets[[i]])

  # The figures print no numbers, so each one's plotted values are written out beside
  # it. Those CSVs are what a reader can diff; a PDF differs on every run because it
  # records the time it was written.
  gg_df |>
    select(facet, variable, condition, Survey, coef, se, li, ui) |>
    write_csv(file.path(out_dir, paste0(nm, ".csv")))

  g <- make_cate_plot(gg_df, panels$title[i])
  ggsave(file.path(out_dir, paste0(nm, ".pdf")), plot = g, width = 8.5, height = 12.5)
  ggsave(file.path(out_dir, paste0(nm, ".png")), plot = g, width = 8.5, height = 12.5,
         dpi = 300)
})
