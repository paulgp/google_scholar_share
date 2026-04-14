suppressPackageStartupMessages(library(tidyverse))

args <- commandArgs(trailingOnly = TRUE)
input_csv <- if (length(args) >= 1) args[[1]] else "paulgp_time_series.csv"
out_dir <- if (length(args) >= 2) args[[2]] else "outputs"

dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

paulgp <- read_csv(
  input_csv,
  col_names = c("year", "cites", "paper"),
  show_col_types = FALSE
)

paper_cites <- paulgp %>% filter(paper != "total")
paper_totals <- paper_cites %>%
  group_by(paper) %>%
  summarise(total_cites = sum(cites), .groups = "drop") %>%
  arrange(desc(total_cites))

latest_total <- paulgp %>%
  filter(paper == "total") %>%
  arrange(desc(year)) %>%
  slice_head(n = 1) %>%
  pull(cites)

latest_total_value <- if (length(latest_total) == 0) NA_real_ else as.numeric(latest_total[[1]])
mean_current_cites <- if (nrow(paper_totals) == 0) NA_real_ else mean(paper_totals$total_cites)
median_current_cites <- if (nrow(paper_totals) == 0) NA_real_ else median(paper_totals$total_cites)

summary_tbl <- tibble(
  metric = c("paper_count", "latest_total_citations", "mean_current_cites", "median_current_cites"),
  value = c(nrow(paper_totals), latest_total_value, mean_current_cites, median_current_cites)
)

hindex_for_year <- function(values) {
  sorted_values <- sort(values, decreasing = TRUE)
  ranks <- seq_along(sorted_values)
  passing <- which(sorted_values >= ranks)
  if (length(passing) == 0) {
    return(0)
  }
  max(passing)
}

all_years <- sort(unique(paulgp$year))

if (nrow(paper_cites) == 0 || length(all_years) == 0) {
  hindex_time <- tibble(year = numeric(), hindex = numeric())
} else {
  hindex_time <- paper_cites %>%
    select(paper, year, cites) %>%
    complete(paper, year = all_years, fill = list(cites = 0)) %>%
    arrange(paper, year) %>%
    group_by(paper) %>%
    mutate(cumulative_cites = cumsum(cites)) %>%
    ungroup() %>%
    group_by(year) %>%
    summarise(hindex = hindex_for_year(cumulative_cites), .groups = "drop")
}

write_csv(summary_tbl, file.path(out_dir, "paulgp_summary.csv"))
write_csv(hindex_time, file.path(out_dir, "paulgp_hindex.csv"))
write_csv(paper_totals, file.path(out_dir, "paulgp_top_papers.csv"))

cat(sprintf("Wrote analysis outputs to %s\n", out_dir))
