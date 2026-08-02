# coppock_mcclellan_2019/maintained/figure_2_standardized_experiments.R
# Output: output/figure_2_standardized_experiments.pdf,
#         output/figure_2_standardized_experiments.png,
#         output/figure_2_standardized_experiments.csv
# Depends on: helpers.R, original/ReplicationArchive/StandardizedExperiments.RData
# Description: Figure 2, standardized treatment effects for the five replicated
#   experiments, the archive's script 10. The facet ordering is set explicitly, as in
#   the archive, rather than relying on the facet_f column the data file also carries.

source(here::here("maintained", "helpers.R"))

load(file.path(data_dir, "StandardizedExperiments.RData"))

gg_df <- experiments_standardized |>
  mutate(facet_f = factor(
    facet,
    levels = c("Welfare", "Asian Disease", "Kam and Simas", "Hiscox", "Berinsky")
  ))

# The figure prints no numbers, so the plotted values are written out beside it. That
# CSV is what a reader can diff; a PDF differs on every run because it records the time
# it was written.
gg_df |>
  select(facet, variable, Variable, survey, Survey, coef, se, li, ui) |>
  write_csv(file.path(out_dir, "figure_2_standardized_experiments.csv"))

g <- ggplot(gg_df,
            aes(x = coef, y = Variable, group = Survey,
                color = Survey, shape = Survey)) +
  geom_point(position = position_dodge(width = 0.5)) +
  geom_linerange(aes(xmin = li, xmax = ui),
                 position = position_dodge(width = 0.5)) +
  geom_vline(xintercept = 0, linetype = "dashed", alpha = 0.5) +
  scale_shape_manual(values = c(17, 16, 15)) +
  scale_color_manual(values = c("#00CC66", "#0099CC", "#CC3333")) +
  facet_grid(facet_f ~ ., scales = "free_y", space = "free_y") +
  coord_cartesian(xlim = c(-1.5, 1.5)) +
  theme_bw() +
  theme(
    axis.title = element_blank(),
    legend.position = "bottom",
    legend.title = element_blank(),
    strip.background = element_blank()
  ) +
  ggtitle("Standardized Treatment Effects For Experimental Replications")

ggsave(file.path(out_dir, "figure_2_standardized_experiments.pdf"),
       plot = g, width = 8.5, height = 12.5)
ggsave(file.path(out_dir, "figure_2_standardized_experiments.png"),
       plot = g, width = 8.5, height = 12.5, dpi = 300)
