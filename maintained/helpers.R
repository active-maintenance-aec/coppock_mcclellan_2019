# coppock_mcclellan_2019/maintained/helpers.R
# Output: none
# Depends on: nothing
# Description: Packages, shared paths, and the helper functions the archive defined by hand.

library(here)

here::i_am("maintained/helpers.R")

library(tidyverse)
library(estimatr)
library(broom)
library(scales)
library(matrixStats)
library(rsample)
library(knitr)
library(kableExtra)
library(modelsummary)

options(modelsummary_format_numeric_latex = "plain")

data_dir <- here::here("original", "ReplicationArchive")
out_dir <- here::here("maintained", "output")

# Standard error of a weighted mean, Cochran (1977) ----
# The archive defines this as weighted.se() in LucidValidationHelperFunctions.R,
# wrapping weighted.var.mean(). It is reproduced here under a snake_case name
# because no maintained package exports it.
weighted_se_mean <- function(x, w, na.rm = FALSE) {
  if (na.rm) {
    keep <- !is.na(x)
    w <- w[keep]
    x <- x[keep]
  }
  n <- length(w)
  xwbar <- weighted.mean(x, w)
  wbar <- mean(w)
  v <- n / ((n - 1) * sum(w)^2) *
    (sum((w * x - wbar * xwbar)^2) -
       2 * xwbar * sum((w - wbar) * (w * x - wbar * xwbar)) +
       xwbar^2 * sum((w - wbar)^2))
  sqrt(v)
}

# Distance to the ANES 2012 benchmark, Coppock and McClellan appendix Table 1 ----
# For each standardized variable, |MTurk - ANES 2012| - |Lucid - ANES 2012|: positive
# when Lucid sits closer to the benchmark. The archive expresses this as a magrittr
# functional sequence built from melt() and dcast(); pivot_longer() and pivot_wider()
# do the same reshape. Three scripts need it, once on the data and twice inside a
# bootstrap, so it lives here rather than being written out three times.
compute_distances <- function(df) {
  df |>
    group_by(survey) |>
    summarize(across(where(is.numeric) & !all_of("weights"),
                     ~ weighted.mean(., w = weights, na.rm = TRUE)),
              .groups = "drop") |>
    pivot_longer(-survey, names_to = "variable", values_to = "mean") |>
    pivot_wider(names_from = survey, values_from = mean) |>
    transmute(variable,
              lucid_is_closer = abs(mturk - anes2012) - abs(lucid - anes2012))
}

# One run of the deposit's whole bootstrap: 100 resamples, the standard error of the
# distance across them. The seed is an argument because the two stability scripts vary
# it deliberately, and the number of resamples is the deposit's 100 rather than a
# default, so no call site can silently disagree with the published procedure.
bootstrap_distance_ses <- function(seed, df, times = 100) {
  set.seed(seed)
  bootstraps(df, times = times) |>
    mutate(model = map(splits, ~ compute_distances(analysis(.x)))) |>
    select(id, model) |>
    unnest(cols = c(model)) |>
    group_by(variable) |>
    summarize(se = sd(lucid_is_closer), .groups = "drop") |>
    mutate(seed = seed)
}

# Formatting ----
fmt2 <- function(x) sprintf("%.2f", as.numeric(x))
add_parens2 <- function(x) paste0("(", fmt2(x), ")")

# Survey-by-variable weighted means and SEs, formatted the way the archive formats
# them: two decimals, SE in parentheses, proportions rescaled to percentages unless
# named in dont_multiply. The four descriptive tables (archive scripts 01, 02, 03
# and 09) differ only in that list, so the shared work lives here.
weighted_mean_se_entries <- function(dat, dont_multiply) {
  dat |>
    group_by(survey) |>
    summarize(
      across(
        where(is.numeric) & !all_of("weights"),
        list(mean = ~ weighted.mean(., w = weights, na.rm = TRUE),
             se = ~ weighted_se_mean(., w = weights, na.rm = TRUE))
      ),
      .groups = "drop"
    ) |>
    pivot_longer(-survey, names_to = c("variable", ".value"),
                 names_sep = "_(?=mean$|se$)") |>
    mutate(
      entry = if_else(
        variable %in% dont_multiply,
        paste0(fmt2(mean), " ", add_parens2(se)),
        paste0(fmt2(100 * mean), " ", add_parens2(100 * se))
      ),
      entry = if_else(str_detect(entry, "NaN|NA"), NA_character_, entry)
    )
}

# Blank a figure PDF's embedded timestamps ----
# R's pdf() device stamps /CreationDate and /ModDate with the wall clock, so an
# otherwise deterministic pipeline writes a different file on every run. The epoch
# string is the same width as what it replaces, which keeps the cross-reference byte
# offsets valid, and a file with no timestamp is left alone.
blank_pdf_timestamps <- function(path) {
  epoch <- charToRaw("D:19700101000000")
  raw_pdf <- readBin(path, "raw", file.size(path))
  hits <- grepRaw("D:[0-9]{14}", raw_pdf, all = TRUE)
  if (length(hits) == 0) return(invisible(path))
  for (h in hits) raw_pdf[h:(h + length(epoch) - 1L)] <- epoch
  writeBin(raw_pdf, path)
  invisible(path)
}
