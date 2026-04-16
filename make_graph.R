suppressPackageStartupMessages({
  library(tidyverse)
  library(patchwork)
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
  if (n == 0) return(numeric())
  if (n == 1) return(min(max(anchor_y[[1]], bottom), top))

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
  if (overflow_top > 0) positions <- positions - overflow_top

  overflow_bottom <- bottom - positions[[n]]
  if (overflow_bottom > 0) positions <- positions + overflow_bottom

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

# --- CLI args and data loading ---
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

# --- Compute totals ---
profile_total_series <- time_series %>%
  filter(paper == "total") %>%
  transmute(year = year, profile_total = cites)

paper_cites <- time_series %>% filter(paper != "total")

if (nrow(profile_total_series) == 0 || nrow(paper_cites) == 0) {
  stop("make_graph.R requires total and paper citation rows")
}

# Clip paper data to the year range of the total series
min_total_year <- min(profile_total_series$year)
paper_cites <- paper_cites %>% filter(year >= min_total_year)

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

# --- Select top N papers by recent share ---
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

other_papers <- recent_share_rank %>%
  filter(!paper %in% selected_papers) %>%
  pull(paper)

# --- Build stacked data for ALL papers + residual ---
residual_label <- "Untracked papers"
all_papers <- c(selected_papers, other_papers)
all_years <- sort(unique(raw_total_series$year))

all_paper_series <- paper_cites %>%
  group_by(year, paper) %>%
  summarise(cites = sum(cites), .groups = "drop") %>%
  complete(year = all_years, paper = all_papers, fill = list(cites = 0))

# Compute residual: profile total minus sum of all tracked papers
tracked_year_totals <- all_paper_series %>%
  group_by(year) %>%
  summarise(tracked_cites = sum(cites), .groups = "drop")

residual_series <- raw_total_series %>%
  left_join(tracked_year_totals, by = "year") %>%
  mutate(
    tracked_cites = coalesce(tracked_cites, 0),
    paper = residual_label,
    cites = pmax(total - tracked_cites, 0)
  ) %>%
  select(year, paper, cites)

all_paper_series <- bind_rows(all_paper_series, residual_series) %>%
  left_join(raw_total_series, by = "year") %>%
  mutate(
    share = if_else(total > 0, cites / total, 0)
  ) %>%
  select(year, paper, cites, share)

# Stack order: selected papers at bottom (biggest first), then other papers, residual on top
stack_levels <- rev(c(rev(selected_papers), rev(other_papers), residual_label))
stack_draw_order <- rev(stack_levels)

composition_data <- all_paper_series %>%
  mutate(paper = factor(paper, levels = stack_levels))

# --- Color palette ---
# Healy-inspired bold palette for top papers
healy_bold <- c(
  "#0F4C81",  # deep blue
  "#C23B22",  # brick red
  "#1A7C6C",  # deep teal
  "#D97925",  # burnt sienna
  "#7B2D8E",  # deep purple
  "#2D8E47",  # forest green
  "#C49B1A",  # dark gold
  "#A04060"   # berry
)

# Muted palette for remaining papers — desaturated earth/pastel tones
n_other <- length(other_papers)
if (n_other > 0) {
  hues <- seq(15, 345, length.out = n_other + 1)[seq_len(n_other)]
  muted_colors <- hcl(h = hues, c = 35, l = 75)
} else {
  muted_colors <- character(0)
}

palette_values <- stats::setNames(
  c(healy_bold[seq_len(length(selected_papers))], muted_colors, "#D5D0C8"),
  c(selected_papers, other_papers, residual_label)
)

# --- Shared x-axis config (needed before building base plot) ---
label_anchor_x <- selection_year + 0.02
label_text_x <- selection_year + 1.15
shared_x_limits <- c(min(all_years), label_text_x + 0.75)
shared_breaks <- scales::pretty_breaks(n = 6)

# --- Labels: extract actual band positions from ggplot ---
# Build a bare area plot to get the real stacked ymin/ymax values
base_area_plot <- ggplot(composition_data, aes(x = year, y = share, fill = paper)) +
  geom_area(position = "stack")
area_layer_data <- layer_data(base_area_plot, 1)

# Map ggplot's integer group back to paper names
paper_levels <- levels(composition_data$paper)
group_lookup <- tibble(group = seq_along(paper_levels), paper_name = paper_levels)

label_data <- area_layer_data %>%
  filter(x == selection_year) %>%
  select(group, ymin, ymax) %>%
  left_join(group_lookup, by = "group") %>%
  filter(paper_name %in% selected_papers) %>%
  mutate(
    paper = factor(paper_name, levels = stack_levels),
    share = ymax - ymin,
    anchor_y = (ymin + ymax) / 2,
    label_name = str_trunc(paper_name, width = 42),
    label = paste0(label_name, " ", scales::percent(share, accuracy = 1))
  ) %>%
  arrange(desc(anchor_y), desc(share), label_name)

label_data <- label_data %>%
  mutate(label_y = spread_label_positions(anchor_y))

label_order_top_to_bottom <- label_data %>% pull(label_name)

# --- Subtitle ---
subtitle_parts <- c(
  paste0(
    "Top ", length(selected_papers),
    " papers labeled by ", selection_year, " share. All papers colored individually."
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

# --- Top panel: total citations line ---
total_plot <- ggplot(plot_total_series, aes(x = year, y = total)) +
  theme_healy() +
  labs(
    title = "A growing share of citations comes from a small number of papers",
    subtitle = subtitle_text,
    y = "Annual citations"
  ) +
  scale_x_continuous(
    breaks = shared_breaks,
    expand = expansion(mult = c(0.01, 0))
  ) +
  scale_y_continuous(labels = scales::label_number(big.mark = ",")) +
  coord_cartesian(xlim = shared_x_limits) +
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
      shape = 21, fill = "#FFFFFF", colour = "#222222", stroke = 0.8, size = 2.6
    )
}

# --- Bottom panel: stacked area of ALL papers ---
share_plot <- ggplot(
  composition_data,
  aes(x = year, y = share, fill = paper)
) +
  geom_area(position = "stack", colour = "white", linewidth = 0.15, alpha = 0.92) +
  geom_segment(
    data = label_data,
    aes(x = label_anchor_x, xend = label_text_x - 0.08,
        y = anchor_y, yend = label_y, colour = paper),
    inherit.aes = FALSE, linewidth = 0.35, show.legend = FALSE
  ) +
  geom_text(
    data = label_data,
    aes(x = label_text_x, y = label_y, label = label, colour = paper),
    inherit.aes = FALSE, hjust = 0, size = 3.0, lineheight = 0.95, show.legend = FALSE
  ) +
  theme_healy() +
  labs(y = "Share of annual citations") +
  scale_x_continuous(
    breaks = shared_breaks,
    expand = expansion(mult = c(0.01, 0))
  ) +
  scale_y_continuous(
    labels = scales::label_percent(accuracy = 1),
    expand = expansion(mult = c(0, 0.02))
  ) +
  scale_fill_manual(values = palette_values) +
  scale_colour_manual(values = palette_values) +
  coord_cartesian(clip = "off", xlim = shared_x_limits, ylim = c(0, 1))

# --- Combine with patchwork ---
combined <- total_plot / share_plot +
  plot_layout(heights = c(0.95, 2.1))

ggsave(output_png, combined, width = 15.5, height = 9.5, units = "in", dpi = 160)

# --- Diagnostics ---
cat(sprintf("Graph design: total_line + share_area, top_n=%s, label_year=%s\n", top_n, selection_year))
cat(sprintf("Total papers colored: %s (top %s labeled)\n", length(all_papers), length(selected_papers)))
cat(sprintf("Selected papers: %s\n", paste(selected_papers, collapse = " | ")))
cat(sprintf("Label order (top-to-bottom): %s\n", paste(label_order_top_to_bottom, collapse = " | ")))
cat(sprintf(
  "Annualized aggregate: year=%s, raw=%s, annualized=%.1f, day_of_year=%s\n",
  latest_total_year, raw_latest_total, annualized_latest_total,
  ifelse(latest_total_year == graph_year, day_of_year, 365)
))
cat(sprintf("Wrote graph to %s\n", output_png))
