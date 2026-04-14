# Healy-Style Citation Composition Figure

**Goal:** Replace the existing stacked bar chart with a cleaner composition-focused figure inspired by Kieran Healy's visual style.

## Approach
- Use a two-panel layout.
- Top panel: total annual citations as a restrained line chart.
- Bottom panel: annual citation-share composition as a 100% stacked area chart.
- Limit featured categories to the top 6 papers by cumulative citations, plus an `All other papers` residual.
- Use direct labels at the right edge instead of a legend.

## Key Decisions
- Keep the existing CLI contract: `Rscript make_graph.R <input_csv> <output_png>`.
- Use muted colors and a light minimal theme.
- When the final year looks partial relative to the previous year, use the previous year for direct-label shares.
- Backfill missing early total-series years with sums from paper-level data so the chart remains well-defined.

## Constraints
- Stay within existing tidyverse + base R grid tooling.
- Avoid adding a new R package dependency just to compose the panels.
- Preserve automated testability from Python smoke tests.

## Success Criteria
- The chart foregrounds composition rather than a crowded legend.
- The output is visually cleaner than the prior stacked bars.
- The script runs without warnings on representative data.
- The PNG output is regenerated through the normal repository workflow.
