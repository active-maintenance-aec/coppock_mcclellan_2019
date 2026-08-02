# coppock_mcclellan_2019/maintained/figure_1_standardized_demos.R
# Output: output/figure_1_standardized_demos.pdf, output/figure_1_standardized_demos.png,
#         output/figure_1_standardized_demos.csv
# Depends on: helpers.R, original/ReplicationArchive/StandardizedDemos.RData
# Description: Figure 1, standardized demographic, political and psychological means on
#   Lucid, MTurk and the 2012 ANES. The archive's script 10 draws it with
#   coefplot::position_dodgev() and geom_errorbarh(); position_dodge() dodges along the
#   discrete y axis natively and geom_linerange() replaces the deprecated geom_errorbarh().

source(here::here("maintained", "helpers.R"))

load(file.path(data_dir, "StandardizedDemos.RData"))

gg_df <- demos_standardized

# The figure prints no numbers, so the plotted values are written out beside it. That
# CSV is what a reader can diff; a PDF differs on every run because it records the time
# it was written.
gg_df |>
  select(facet, variable, Variable, survey, Survey, mean, se, li, ui) |>
  write_csv(file.path(out_dir, "figure_1_standardized_demos.csv"))

g <- ggplot(gg_df,
            aes(x = mean, y = Variable, group = Survey,
                color = Survey, shape = Survey)) +
  geom_point(position = position_dodge(width = 0.5)) +
  geom_linerange(aes(xmin = li, xmax = ui),
                 position = position_dodge(width = 0.5)) +
  geom_vline(xintercept = 0, linetype = "dashed", alpha = 0.5) +
  scale_shape_manual(values = c(15, 16, 17)) +
  scale_color_manual(values = c("#CC3333", "#0099CC", "#00CC66")) +
  facet_grid(facet ~ ., scales = "free_y", space = "free_y") +
  coord_cartesian(xlim = c(-1, 1)) +
  theme_bw() +
  theme(
    axis.title = element_blank(),
    legend.position = "bottom",
    legend.title = element_blank(),
    strip.background = element_blank()
  ) +
  ggtitle("Standardized Means for Demographic Variables")

ggsave(file.path(out_dir, "figure_1_standardized_demos.pdf"),
       plot = g, width = 8, height = 10)
ggsave(file.path(out_dir, "figure_1_standardized_demos.png"),
       plot = g, width = 8, height = 10, dpi = 300)
