suppressPackageStartupMessages({
  library(tidyverse)
  library(grid)
})

args <- commandArgs(trailingOnly = TRUE)
input_csv <- if (length(args) >= 1) args[[1]] else "paulgp_time_series.csv"
output_png <- if (length(args) >= 2) args[[2]] else "outputs/paulgp_citation_share.png"
top_n <- 6

dir.create(dirname(output_png), recursive = TRUE, showWarnings = FALSE)

time_series <- read_csv(
  input_csv,
  col_names = c("year", "cites", "paper"),
  show_col_types = FALSE
)

profile_total_series <- time_series %>%
  filter(paper == "total") %>%
  transmute(year = year, profile_total = cites)

paper_cites <- time_series %>% filter(paper != "total")

if (nrow(profile_total_series) == 0 || nrow(paper_cites) == 0) {
  stop("make_graph.R requires total and paper citation rows")
}

paper_year_totals <- paper_cites %>%
  group_by(year) %>%
  summarise(paper_total = sum(cites), .groups = "drop")

total_series <- full_join(profile_total_series, paper_year_totals, by = "year") %>%
  mutate(total = coalesce(profile_total, paper_total)) %>%
  select(year, total) %>%
  arrange(year)

paper_totals <- paper_cites %>%
  group_by(paper) %>%
  summarise(total_cites = sum(cites), .groups = "drop") %>%
  arrange(desc(total_cites), paper)

top_papers <- paper_totals %>%
  slice_head(n = min(top_n, nrow(paper_totals))) %>%
  pull(paper)

all_years <- sort(unique(total_series$year))
max_year <- max(all_years)
label_year <- max_year

if (length(all_years) >= 2) {
  latest_total <- total_series %>% filter(year == all_years[length(all_years)]) %>% pull(total)
  previous_total <- total_series %>% filter(year == all_years[length(all_years) - 1]) %>% pull(total)
  if (length(latest_total) == 1 && length(previous_total) == 1 && latest_total < previous_total) {
    label_year <- all_years[length(all_years) - 1]
  }
}

composition_data <- paper_cites %>%
  mutate(paper_group = if_else(paper %in% top_papers, paper, "All other papers")) %>%
  group_by(year, paper_group) %>%
  summarise(cites = sum(cites), .groups = "drop") %>%
  complete(year = all_years, paper_group = c(top_papers, "All other papers"), fill = list(cites = 0)) %>%
  left_join(total_series, by = "year") %>%
  mutate(share = if_else(total > 0, cites / total, 0))

share_order <- composition_data %>%
  filter(year == label_year, paper_group != "All other papers") %>%
  arrange(share, paper_group) %>%
  pull(paper_group)

fill_levels <- unique(c("All other papers", share_order, setdiff(top_papers, share_order)))

composition_data <- composition_data %>%
  mutate(paper_group = factor(paper_group, levels = fill_levels))

label_data <- composition_data %>%
  filter(year == label_year) %>%
  arrange(paper_group) %>%
  mutate(
    ymax = cumsum(share),
    y = ymax - share / 2,
    label_name = if_else(
      paper_group == "All other papers",
      "All other papers",
      str_trunc(as.character(paper_group), width = 40)
    ),
    label = paste0(label_name, " ", scales::percent(share, accuracy = 1))
  )

label_x <- max_year + 0.6

accent_colors <- c("#4E79A7", "#59A14F", "#F28E2B", "#E15759", "#76B7B2", "#B07AA1")
palette_values <- c("All other papers" = "#D9D9D9")
if (length(fill_levels) > 1) {
  palette_values <- c(
    palette_values,
    stats::setNames(accent_colors[seq_len(length(fill_levels) - 1)], fill_levels[-1])
  )
}

theme_healy <- function() {
  theme_minimal(base_size = 12) +
    theme(
      panel.grid.minor = element_blank(),
      panel.grid.major.x = element_blank(),
      panel.grid.major.y = element_line(linewidth = 0.25, colour = "#D0D0D0"),
      legend.position = "none",
      plot.title.position = "plot",
      axis.title.x = element_blank(),
      axis.text = element_text(colour = "#444444"),
      axis.title.y = element_text(colour = "#444444"),
      plot.title = element_text(face = "bold", size = 16, colour = "#222222"),
      plot.subtitle = element_text(size = 10.5, colour = "#444444"),
      plot.margin = margin(8, 90, 8, 8)
    )
}

subtitle_text <- paste0(
  "Top ", length(top_papers),
  " papers by cumulative citations plus all other papers. ",
  if (label_year < max_year) {
    paste0("Labels show ", label_year, " shares; ", max_year, " is year-to-date.")
  } else {
    "Bottom panel shows annual citation shares."
  }
)

full_total_plot <- ggplot(total_series, aes(x = year, y = total))

if (label_year < max_year) {
  total_plot <- full_total_plot +
    geom_line(
      data = total_series %>% filter(year <= label_year),
      colour = "#222222",
      linewidth = 0.65
    ) +
    geom_point(
      data = total_series %>% filter(year <= label_year),
      colour = "#222222",
      size = 1.6
    ) +
    geom_line(
      data = total_series %>% filter(year >= label_year),
      colour = "#8C8C8C",
      linewidth = 0.6,
      linetype = "22"
    ) +
    geom_point(
      data = total_series %>% filter(year == max_year),
      colour = "#8C8C8C",
      size = 1.6
    )
} else {
  total_plot <- full_total_plot +
    geom_line(colour = "#222222", linewidth = 0.65) +
    geom_point(colour = "#222222", size = 1.6)
}

total_plot <- total_plot +
  theme_healy() +
  labs(
    title = "A growing share of citations comes from a small number of papers",
    subtitle = subtitle_text,
    y = "Annual citations"
  ) +
  scale_x_continuous(
    breaks = scales::pretty_breaks(n = 6),
    expand = expansion(mult = c(0.01, 0.02))
  ) +
  scale_y_continuous(labels = scales::label_number(big.mark = ",")) +
  theme(
    axis.text.x = element_blank(),
    axis.ticks.x = element_blank(),
    plot.margin = margin(8, 90, 0, 8)
  )

share_plot <- ggplot(
  composition_data,
  aes(x = year, y = share, fill = paper_group)
) +
  geom_area(stat = "identity", colour = "white", linewidth = 0.2, alpha = 0.98) +
  geom_segment(
    data = label_data,
    aes(x = label_year, xend = label_x - 0.05, y = y, yend = y, colour = paper_group),
    inherit.aes = FALSE,
    linewidth = 0.35,
    show.legend = FALSE
  ) +
  geom_text(
    data = label_data,
    aes(x = label_x, y = y, label = label, colour = paper_group),
    inherit.aes = FALSE,
    hjust = 0,
    size = 3.1,
    show.legend = FALSE
  ) +
  theme_healy() +
  labs(
    y = "Share of annual citations"
  ) +
  scale_x_continuous(
    breaks = scales::pretty_breaks(n = 6),
    expand = expansion(mult = c(0.01, 0.18))
  ) +
  scale_y_continuous(
    labels = scales::label_percent(accuracy = 1),
    expand = expansion(mult = c(0, 0.02))
  ) +
  scale_fill_manual(values = palette_values) +
  scale_colour_manual(values = palette_values) +
  coord_cartesian(clip = "off")

png(output_png, width = 12, height = 9, units = "in", res = 160)
grid.newpage()
pushViewport(viewport(layout = grid.layout(nrow = 2, ncol = 1, heights = unit(c(0.9, 2), "null"))))
print(total_plot, vp = viewport(layout.pos.row = 1, layout.pos.col = 1))
print(share_plot, vp = viewport(layout.pos.row = 2, layout.pos.col = 1))
invisible(dev.off())

cat(sprintf("Graph design: total_line + share_area, top_n=%s, label_year=%s\n", top_n, label_year))
cat(sprintf("Wrote graph to %s\n", output_png))
