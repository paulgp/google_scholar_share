# Healy Graph Follow-Ups Implementation Plan

**Goal:** Fix label ordering and readability in the Healy-style graph, choose labeled papers using the most recent shares, and annualize the current-year aggregate citation total based on the day of year.
**Architecture:** Keep `make_graph.R` as the single graph entrypoint, but refactor its data-prep layer to compute a graph year table with an annualized current-year aggregate, select featured papers using most recent observed shares, and generate non-overlapping right-edge labels in the correct top-to-bottom order. Add regression tests that validate label ordering, paper selection, warning-free rendering, and current-year annualization through deterministic test fixtures.
**Tech Stack:** R (`tidyverse`, `grid`), Python `unittest`, PNG graph output.

- [x] Task 1: Add failing regression tests for current-year annualization, recent-share selection, and label-order metadata ✅
- [x] Task 2: Refactor `make_graph.R` data preparation and label layout to satisfy the new graph requirements ✅
- [x] Task 3: Regenerate the graph and verify the full test suite ✅

### Task 1: Add failing regression tests for current-year annualization, recent-share selection, and label-order metadata

**Files:**
- Modify: `tests/test_scholar_pipeline.py`
- Create: `tests/data/sample_time_series_share_order.csv`
- Test: `tests/test_scholar_pipeline.py`

**Step 1: Write the failing test**
Add a test fixture with enough papers to check: (a) selected papers come from the most recent year shares, (b) label order is top-to-bottom rather than reversed, and (c) the current year annualizes using a provided test date override. Assert against structured stdout such as:
```text
Graph design: total_line + share_area, top_n=8, label_year=2026
Label order (top-to-bottom): Paper A | Paper B | ...
Selected papers: Paper A | Paper B | ...
Annualized aggregate: year=2026, raw=100, annualized=354
```

**Step 2: Run test to verify it fails**
Run: `.venv/bin/python -m unittest tests.test_scholar_pipeline.RScriptSmokeTests.test_make_graph_r_uses_recent_shares_and_annualizes_current_year -v`
Expected: FAIL because `make_graph.R` currently selects by cumulative totals, reports reversed label order, and does not annualize the current-year aggregate.

**Step 3: Write minimal implementation**
Use stdout metadata to make graph internals testable without changing the public CLI.

**Step 4: Run test to verify it passes**
Run: `.venv/bin/python -m unittest tests.test_scholar_pipeline.RScriptSmokeTests.test_make_graph_r_uses_recent_shares_and_annualizes_current_year -v`
Expected: PASS.

**Step 5: Commit**
```bash
git add tests/test_scholar_pipeline.py tests/data/sample_time_series_share_order.csv
git commit -m "test: cover healy graph follow-up requirements"
```

### Task 2: Refactor `make_graph.R` data preparation and label layout to satisfy the new graph requirements

**Files:**
- Modify: `make_graph.R`
- Test: `tests/test_scholar_pipeline.py`

**Step 1: Write the failing test**
Extend the smoke test to require warning-free rendering and a larger label set.

**Step 2: Run test to verify it fails**
Run: `.venv/bin/python -m unittest tests.test_scholar_pipeline.RScriptSmokeTests -v`
Expected: FAIL until the graph uses recent-share ranking, a non-overlapping label layout, correct label ordering, and annualized latest aggregate totals.

**Step 3: Write minimal implementation**
Implement:
- featured-paper selection by most recent available paper shares
- a larger featured set (8 papers)
- top-to-bottom label ordering that matches the plotted shares
- non-overlapping right-edge labels with deterministic top-to-bottom spacing
- annualized latest aggregate total based on `Sys.Date()` day-of-year, with a test override env var
- updated subtitle / metadata reflecting the annualized current-year point

**Step 4: Run test to verify it passes**
Run: `.venv/bin/python -m unittest tests.test_scholar_pipeline.RScriptSmokeTests -v`
Expected: PASS.

**Step 5: Commit**
```bash
git add make_graph.R tests/test_scholar_pipeline.py
git commit -m "feat: refine healy graph labels and annualize current year"
```

### Task 3: Regenerate the graph and verify the full test suite

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
git commit -m "chore: refresh healy graph output"
```
