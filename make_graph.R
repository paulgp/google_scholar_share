suppressPackageStartupMessages(library(tidyverse))

args <- commandArgs(trailingOnly = TRUE)
input_csv <- if (length(args) >= 1) args[[1]] else "paulgp_time_series.csv"
output_png <- if (length(args) >= 2) args[[2]] else "outputs/paulgp_citation_share.png"

dir.create(dirname(output_png), recursive = TRUE, showWarnings = FALSE)

time_series <- read_csv(
  input_csv,
  col_names = c("year", "cites", "paper"),
  show_col_types = FALSE
)

total_cites <- time_series %>% filter(paper == "total")
paper_cites <- time_series %>% filter(paper != "total")

paper_totals <- paper_cites %>%
  group_by(paper) %>%
  summarise(total_cites = sum(cites), .groups = "drop")

top_papers <- paper_totals %>%
  arrange(desc(total_cites)) %>%
  slice_head(n = 20) %>%
  pull(paper)

paper_cites_top <- paper_cites %>% filter(paper %in% top_papers)

total_lookup <- total_cites %>% transmute(year = year, total = cites)

residual_cites <- paper_cites_top %>%
  group_by(year) %>%
  summarise(displayed_cites = sum(cites), .groups = "drop") %>%
  right_join(total_lookup, by = "year") %>%
  mutate(displayed_cites = coalesce(displayed_cites, 0)) %>%
  mutate(cites = pmax(total - displayed_cites, 0)) %>%
  mutate(paper = "All other papers") %>%
  select(year, cites, paper, total)

plot_data <- paper_cites_top %>%
  inner_join(total_lookup, by = "year") %>%
  bind_rows(residual_cites) %>%
  mutate(paper_trim = str_trunc(paper, width = 60))

label_years <- sort(unique(plot_data$year))
label_year <- if (length(label_years) >= 2) label_years[length(label_years) - 1] else label_years[length(label_years)]

plot_data <- plot_data %>%
  mutate(share = if_else(year == label_year, scales::percent(cites / total, accuracy = 1), NA_character_))

new_levels <- plot_data %>%
  filter(year == label_year) %>%
  arrange(cites / total) %>%
  pull(paper_trim)

if (length(new_levels) == 0) {
  new_levels <- unique(plot_data$paper_trim)
}

plot_object <- ggplot(
  data = plot_data %>% mutate(paper_trim = factor(paper_trim, levels = new_levels)),
  aes(y = cites, x = year)
) +
  geom_col(aes(fill = paper_trim), color = "black") +
  geom_text(
    aes(group = paper_trim, label = share),
    position = position_stack(vjust = 0.5),
    na.rm = TRUE,
    size = 3
  ) +
  theme_minimal() +
  labs(
    title = "Cites from Google Scholar for Paul Goldsmith-Pinkham over time",
    y = "",
    subtitle = "Top 20 papers",
    fill = "Paper Title",
    x = ""
  )

ggsave(output_png, plot = plot_object, width = 12, height = 8, dpi = 150)
cat(sprintf("Wrote graph to %s\n", output_png))
