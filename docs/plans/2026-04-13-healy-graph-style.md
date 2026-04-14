# Healy-Style Graph Implementation Plan

**Goal:** Update `make_graph.R` to produce a cleaner composition-focused figure in a Kieran Healy-inspired style while preserving the existing CLI workflow.
**Architecture:** Replace the single stacked bar chart with a two-panel composition figure: a top panel for total annual citations and a bottom panel for annual citation shares among the top papers plus an "All other papers" residual. Keep the script as a standalone R entrypoint and add regression tests that verify the new output metadata and chart generation behavior.
**Tech Stack:** R (`tidyverse`, `ggplot2`, `grid`), Python `unittest` smoke tests.

- [x] Task 1: Add failing regression tests for the new graph metadata and output behavior ✅
- [x] Task 2: Refactor `make_graph.R` to build the Healy-style two-panel composition chart ✅
- [x] Task 3: Regenerate the graph output and verify the full test suite ✅

### Task 1: Add failing regression tests for the new graph metadata and output behavior

**Files:**
- Modify: `tests/test_scholar_pipeline.py`
- Test: `tests/data/sample_time_series.csv`

**Step 1: Write the failing test**
Add a test that runs `make_graph.R`, captures stdout, and asserts that the script reports the new design elements: a top-panel total series and a bottom-panel share composition with top 6 papers plus residual.

**Step 2: Run test to verify it fails**
Run: `.venv/bin/python -m unittest tests.test_scholar_pipeline.RScriptSmokeTests.test_make_graph_r_reports_healy_style_components -v`
Expected: FAIL because the current script only writes a generic PNG message and still uses a stacked bar chart design.

**Step 3: Write minimal implementation**
Update `make_graph.R` so it emits a structured status line describing the generated graph components, e.g. `Graph design: total_line + share_area, top_n=6`.

**Step 4: Run test to verify it passes**
Run: `.venv/bin/python -m unittest tests.test_scholar_pipeline.RScriptSmokeTests.test_make_graph_r_reports_healy_style_components -v`
Expected: PASS.

**Step 5: Commit**
```bash
git add tests/test_scholar_pipeline.py make_graph.R
git commit -m "test: cover healy style graph output"
```

### Task 2: Refactor `make_graph.R` to build the Healy-style two-panel composition chart

**Files:**
- Modify: `make_graph.R`
- Test: `tests/test_scholar_pipeline.py`

**Step 1: Write the failing test**
Extend the existing smoke test expectations to validate the new stdout metadata and successful PNG generation together.

**Step 2: Run test to verify it fails**
Run: `.venv/bin/python -m unittest tests.test_scholar_pipeline.RScriptSmokeTests -v`
Expected: FAIL on the metadata assertion while the old PNG smoke test may still pass.

**Step 3: Write minimal implementation**
Implement:
- top 6 papers by cumulative citations + residual
- top panel line chart for total annual citations
- bottom panel 100% stacked area chart of shares
- restrained theme, muted palette, minimal grid, no legend
- right-edge direct labels for the composition panel
- single PNG output using base `grid` layout

**Step 4: Run test to verify it passes**
Run: `.venv/bin/python -m unittest tests.test_scholar_pipeline.RScriptSmokeTests -v`
Expected: PASS.

**Step 5: Commit**
```bash
git add make_graph.R tests/test_scholar_pipeline.py
git commit -m "feat: switch to healy-style composition graph"
```

### Task 3: Regenerate the graph output and verify the full test suite

**Files:**
- Modify: `outputs/paulgp_citation_share.png`

**Step 1: Regenerate the graph**
Run: `Rscript make_graph.R paulgp_time_series.csv outputs/paulgp_citation_share.png`
Expected: updated graph PNG is written.

**Step 2: Run the full test suite**
Run: `.venv/bin/python -m unittest discover -s tests -v`
Expected: PASS.

**Step 3: Commit**
```bash
git add outputs/paulgp_citation_share.png
git commit -m "chore: refresh healy style graph output"
```
