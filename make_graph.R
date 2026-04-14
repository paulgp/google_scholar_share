suppressPackageStartupMessages({
  library(tidyverse)
  library(grid)
})

resolve_graph_today <- function() {
  override <- Sys.getenv("MAKE_GRAPH_TODAY", "")
  if (nzchar(override)) {
    return(as.Date(override))
  }
  Sys.Date()
}

spread_label_positions <- function(anchor_y, top = 0.97, bottom = 0.03) {
  n <- length(anchor_y)
  if (n == 0) {
    return(numeric())
  }
  if (n == 1) {
    return(min(max(anchor_y[[1]], bottom), top))
  }

  min_gap <- min(0.055, (top - bottom) / (n - 1))
  positions <- anchor_y
  positions[[1]] <- min(anchor_y[[1]], top)

  for (i in 2:n) {
    positions[[i]] <- min(anchor_y[[i]], positions[[i - 1]] - min_gap)
  }

  lower_bounds <- bottom + rev(seq_len(n) - 1) * min_gap
  positions <- pmax(positions, lower_bounds)

  for (i in seq(from = n - 1, to = 1)) {
    positions[[i]] <- max(positions[[i]], positions[[i + 1]] + min_gap)
  }

  overflow_top <- positions[[1]] - top
  if (overflow_top > 0) {
    positions <- positions - overflow_top
  }

  overflow_bottom <- bottom - positions[[n]]
  if (overflow_bottom > 0) {
    positions <- positions + overflow_bottom
  }

  positions
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
      plot.margin = margin(8, 150, 8, 8)
    )
}

args <- commandArgs(trailingOnly = TRUE)
input_csv <- if (length(args) >= 1) args[[1]] else "paulgp_time_series.csv"
output_png <- if (length(args) >= 2) args[[2]] else "outputs/paulgp_citation_share.png"
top_n <- 8

dir.create(dirname(output_png), recursive = TRUE, showWarnings = FALSE)

time_series <- read_csv(
  input_csv,
  col_names = c("year", "cites", "paper"),
  show_col_types = FALSE
)

graph_today <- resolve_graph_today()
graph_year <- as.integer(format(graph_today, "%Y"))
day_of_year <- as.integer(format(graph_today, "%j"))

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

raw_total_series <- full_join(profile_total_series, paper_year_totals, by = "year") %>%
  mutate(total = coalesce(profile_total, paper_total)) %>%
  select(year, total) %>%
  arrange(year)

latest_total_year <- max(raw_total_series$year)
raw_latest_total <- raw_total_series %>%
  filter(year == latest_total_year) %>%
  pull(total) %>%
  .[[1]]

annualized_latest_total <- as.numeric(raw_latest_total)
if (latest_total_year == graph_year && day_of_year > 0 && day_of_year < 365) {
  annualized_latest_total <- raw_latest_total * 365 / day_of_year
}

plot_total_series <- raw_total_series %>%
  mutate(total = if_else(year == latest_total_year, annualized_latest_total, as.numeric(total)))

selection_year <- max(paper_cites$year)
selection_total <- raw_total_series %>%
  filter(year == selection_year) %>%
  pull(total) %>%
  .[[1]]

recent_share_rank <- paper_cites %>%
  group_by(paper) %>%
  summarise(
    recent_cites = sum(cites[year == selection_year]),
    cumulative_cites = sum(cites),
    .groups = "drop"
  ) %>%
  mutate(recent_share = if (selection_total > 0) recent_cites / selection_total else 0) %>%
  arrange(desc(recent_share), desc(recent_cites), desc(cumulative_cites), paper)

selected_papers <- recent_share_rank %>%
  slice_head(n = min(top_n, nrow(recent_share_rank))) %>%
  pull(paper)

stack_levels <- c("All other papers", rev(selected_papers))
all_years <- sort(unique(raw_total_series$year))

composition_data <- paper_cites %>%
  mutate(paper_group = if_else(paper %in% selected_papers, paper, "All other papers")) %>%
  group_by(year, paper_group) %>%
  summarise(cites = sum(cites), .groups = "drop") %>%
  complete(year = all_years, paper_group = stack_levels, fill = list(cites = 0)) %>%
  left_join(raw_total_series, by = "year") %>%
  mutate(
    share = if_else(total > 0, cites / total, 0),
    paper_group = factor(paper_group, levels = stack_levels)
  )

label_data <- composition_data %>%
  filter(year == selection_year) %>%
  arrange(paper_group) %>%
  mutate(
    ymax = cumsum(share),
    anchor_y = ymax - share / 2,
    label_name = if_else(
      as.character(paper_group) == "All other papers",
      "All other papers",
      str_trunc(as.character(paper_group), width = 42)
    ),
    label = paste0(label_name, " ", scales::percent(share, accuracy = 1))
  ) %>%
  arrange(desc(anchor_y), desc(share), label_name)

label_data <- label_data %>%
  mutate(label_y = spread_label_positions(anchor_y))

label_order_top_to_bottom <- label_data %>% pull(label_name)
label_anchor_x <- selection_year + 0.02
label_text_x <- selection_year + 1.15

accent_colors <- c(
  "#4E79A7", "#59A14F", "#F28E2B", "#E15759",
  "#76B7B2", "#B07AA1", "#EDC948", "#9C755F"
)
palette_values <- c("All other papers" = "#D9D9D9")
if (length(selected_papers) > 0) {
  palette_values <- c(
    palette_values,
    stats::setNames(accent_colors[seq_len(length(selected_papers))], selected_papers)
  )
}

subtitle_parts <- c(
  paste0(
    "Bottom panel labels the top ", length(selected_papers),
    " papers by ", selection_year, " share plus all other papers."
  )
)
if (latest_total_year == graph_year && day_of_year > 0 && day_of_year < 365) {
  subtitle_parts <- c(
    subtitle_parts,
    paste0(
      latest_total_year, " total annualized from ",
      scales::comma(raw_latest_total), " citations through ", as.character(graph_today), "."
    )
  )
}
subtitle_text <- paste(subtitle_parts, collapse = " ")

total_plot <- ggplot(plot_total_series, aes(x = year, y = total)) +
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
    plot.margin = margin(8, 150, 0, 8)
  )

if (nrow(plot_total_series) > 1) {
  total_plot <- total_plot +
    geom_line(aes(group = 1), colour = "#222222", linewidth = 0.7)
}

total_plot <- total_plot +
  geom_point(colour = "#222222", size = 1.7)

if (latest_total_year == graph_year && day_of_year > 0 && day_of_year < 365) {
  total_plot <- total_plot +
    geom_point(
      data = plot_total_series %>% filter(year == latest_total_year),
      shape = 21,
      fill = "#FFFFFF",
      colour = "#222222",
      stroke = 0.8,
      size = 2.6
    )
}

share_plot <- ggplot(
  composition_data,
  aes(x = year, y = share, fill = paper_group)
) +
  geom_area(stat = "identity", colour = "white", linewidth = 0.25, alpha = 0.98) +
  geom_segment(
    data = label_data,
    aes(x = label_anchor_x, xend = label_text_x - 0.08, y = anchor_y, yend = label_y, colour = paper_group),
    inherit.aes = FALSE,
    linewidth = 0.35,
    show.legend = FALSE
  ) +
  geom_text(
    data = label_data,
    aes(x = label_text_x, y = label_y, label = label, colour = paper_group),
    inherit.aes = FALSE,
    hjust = 0,
    size = 3.0,
    lineheight = 0.95,
    show.legend = FALSE
  ) +
  theme_healy() +
  labs(y = "Share of annual citations") +
  scale_x_continuous(
    breaks = scales::pretty_breaks(n = 6),
    expand = expansion(mult = c(0.01, 0.22))
  ) +
  scale_y_continuous(
    labels = scales::label_percent(accuracy = 1),
    expand = expansion(mult = c(0, 0.02))
  ) +
  scale_fill_manual(values = palette_values) +
  scale_colour_manual(values = palette_values) +
  coord_cartesian(
    clip = "off",
    xlim = c(min(all_years), label_text_x + 0.75),
    ylim = c(0, 1)
  )

png(output_png, width = 12.5, height = 9.5, units = "in", res = 160)
grid.newpage()
pushViewport(viewport(layout = grid.layout(nrow = 2, ncol = 1, heights = unit(c(0.95, 2.1), "null"))))
print(total_plot, vp = viewport(layout.pos.row = 1, layout.pos.col = 1))
print(share_plot, vp = viewport(layout.pos.row = 2, layout.pos.col = 1))
invisible(dev.off())

cat(sprintf("Graph design: total_line + share_area, top_n=%s, label_year=%s\n", top_n, selection_year))
cat(sprintf("Selected papers: %s\n", paste(selected_papers, collapse = " | ")))
cat(sprintf("Label order (top-to-bottom): %s\n", paste(label_order_top_to_bottom, collapse = " | ")))
cat(sprintf(
  "Annualized aggregate: year=%s, raw=%s, annualized=%.1f, day_of_year=%s\n",
  latest_total_year,
  raw_latest_total,
  annualized_latest_total,
  ifelse(latest_total_year == graph_year, day_of_year, 365)
))
cat(sprintf("Wrote graph to %s\n", output_png))
